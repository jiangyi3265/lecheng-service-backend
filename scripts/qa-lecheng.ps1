param([string]$BaseUrl = 'http://127.0.0.1:8080')

$ErrorActionPreference = 'Stop'
if (-not $env:LC_QA_ADMIN_PASS) { throw 'Set LC_QA_ADMIN_PASS before running the integration test.' }
$adminName = if ($env:LC_QA_ADMIN_USER) { $env:LC_QA_ADMIN_USER } else { 'admin' }
$base = $BaseUrl.TrimEnd('/')
$guestToken = ''
$qaId = 'qa-news-' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

function Assert-Ok($response, $label) {
  if ($response.code -ne 200) { throw "$label failed: $($response.msg)" }
}
function Send-Json($url, $method, $value, $headers) {
  $body = $value | ConvertTo-Json -Depth 15 -Compress
  Invoke-RestMethod -Uri $url -Method $method -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
}

try {
  $captcha = Invoke-RestMethod -Uri "$base/captchaImage"
  $code = if ($captcha.captchaEnabled) { (& redis-cli --raw GET ('captcha_codes:' + $captcha.uuid)).Trim('"') } else { '' }
  $login = Send-Json "$base/login" 'POST' @{ username=$adminName; password=$env:LC_QA_ADMIN_PASS; code=$code; uuid=$captcha.uuid } @{}
  Assert-Ok $login 'admin login'
  $admin = @{ Authorization = 'Bearer ' + $login.token }

  $session = Invoke-RestMethod -Uri "$base/open/lecheng/session" -Method Post
  Assert-Ok $session 'guest session'
  $guestToken = $session.data.token
  $guest = @{ 'X-Lecheng-Session' = $guestToken }

  $content = Invoke-RestMethod -Uri "$base/open/lecheng/content/hospital"
  Assert-Ok $content 'public hospital catalog'
  if ($content.data.Count -lt 1) { throw 'hospital catalog is empty' }

  $newContent = @{ id=$qaId; kindCode='news'; title='三端联调资讯'; summary='联调测试'; paragraphs=@('联调测试段落'); scene=0; status='1'; sortOrder=9999 }
  Assert-Ok (Send-Json "$base/lecheng/content" 'POST' $newContent $admin) 'admin content save'
  $news = Invoke-RestMethod -Uri "$base/open/lecheng/content/news"
  if (-not ($news.data | Where-Object id -eq $qaId)) { throw 'admin content is not visible through mini-program API' }
  Write-Output 'PASS: admin content -> mini-program catalog'

  Assert-Ok (Send-Json "$base/open/lecheng/messages" 'POST' @{text='联调咨询消息'} $guest) 'guest message'
  $threads = Invoke-RestMethod -Uri "$base/lecheng/consultations" -Headers $admin
  $thread = $threads.data | Where-Object lastMessage -eq '联调咨询消息' | Select-Object -First 1
  if (-not $thread) { throw 'guest message is absent from operator inbox' }
  Assert-Ok (Send-Json "$base/lecheng/consultations/$($thread.sessionId)/reply" 'POST' @{text='联调客服回复'} $admin) 'operator reply'
  $messages = Invoke-RestMethod -Uri "$base/open/lecheng/messages" -Headers $guest
  if (-not ($messages.data | Where-Object text -eq '联调客服回复')) { throw 'operator reply is absent from mini-program conversation' }
  Write-Output 'PASS: guest message -> operator reply -> guest conversation'

  $booking = Send-Json "$base/open/lecheng/appointments" 'POST' @{
    name='联调用户'; phone='13800000000'; doctorId='international-0';
    date=(Get-Date).AddDays(1).ToString('yyyy-MM-dd'); slot='09:00–09:30'; note='联调测试'
  } $guest
  Assert-Ok $booking 'guest appointment'
  $bookingId = [int]($booking.data.id -replace '^LC','')
  $adminBookings = Invoke-RestMethod -Uri "$base/lecheng/appointments" -Headers $admin
  if (-not ($adminBookings.data | Where-Object id -eq $booking.data.id)) { throw 'appointment is absent from operator list' }
  Assert-Ok (Send-Json "$base/lecheng/appointments/$bookingId" 'PUT' @{status='已联系'} $admin) 'operator appointment update'
  $guestBookings = Invoke-RestMethod -Uri "$base/open/lecheng/appointments" -Headers $guest
  if (($guestBookings.data | Where-Object id -eq $booking.data.id).status -ne '已联系') { throw 'appointment status did not sync to guest' }
  Write-Output 'PASS: guest appointment -> operator status -> guest record'

  $cancelBooking = Send-Json "$base/open/lecheng/appointments" 'POST' @{
    name='联调取消用户'; phone='13800000000'; doctorId='international-0';
    date=(Get-Date).AddDays(2).ToString('yyyy-MM-dd'); slot='10:00–10:30'; note='取消测试'
  } $guest
  Assert-Ok $cancelBooking 'guest cancellable appointment'
  $cancelId = [int]($cancelBooking.data.id -replace '^LC','')
  Assert-Ok (Invoke-RestMethod -Uri "$base/open/lecheng/appointments/$cancelId" -Method Delete -Headers $guest) 'guest appointment cancel'
  $cancelled = Invoke-RestMethod -Uri "$base/open/lecheng/appointments" -Headers $guest
  if (($cancelled.data | Where-Object id -eq $cancelBooking.data.id).status -ne '已取消') { throw 'guest cancellation did not persist' }
  Write-Output 'PASS: guest appointment cancellation persists'

  $feedback = Send-Json "$base/open/lecheng/feedback" 'POST' @{text='联调反馈内容'} $guest
  Assert-Ok $feedback 'guest feedback'
  $adminFeedback = Invoke-RestMethod -Uri "$base/lecheng/feedback" -Headers $admin
  if (-not ($adminFeedback.data | Where-Object id -eq $feedback.data.id)) { throw 'feedback is absent from operator list' }
  Assert-Ok (Send-Json "$base/lecheng/feedback/$($feedback.data.id)" 'PUT' @{status='已处理'} $admin) 'operator feedback update'
  $guestFeedback = Invoke-RestMethod -Uri "$base/open/lecheng/feedback" -Headers $guest
  if (($guestFeedback.data | Where-Object id -eq $feedback.data.id).status -ne '已处理') { throw 'feedback status did not sync to guest' }
  Write-Output 'PASS: guest feedback -> operator status -> guest record'

  $delete = Invoke-RestMethod -Uri "$base/lecheng/content/$qaId" -Method Delete -Headers $admin
  Assert-Ok $delete 'admin content delete'
  Write-Output 'PASS: content deletion'
}
finally {
  if ($guestToken) {
    $bytes = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($guestToken))
    $hash = [Convert]::ToHexString($bytes).ToLowerInvariant()
    $config = Get-Content (Join-Path $PSScriptRoot '../ruoyi-admin/src/main/resources/application-druid.yml') -Raw
    $password = [regex]::Match($config, '(?m)^\s*password:\s*(\S+)').Groups[1].Value
    $env:MYSQL_PWD = $password
    try {
      & mysql -uroot -D ha -e "DELETE FROM lc_message WHERE session_hash='$hash'; DELETE FROM lc_appointment WHERE session_hash='$hash'; DELETE FROM lc_feedback WHERE session_hash='$hash'; DELETE FROM lc_client WHERE session_hash='$hash';"
    } finally { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue }
  }
}
