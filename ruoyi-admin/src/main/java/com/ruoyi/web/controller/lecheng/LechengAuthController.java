package com.ruoyi.web.controller.lecheng;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.util.UriComponentsBuilder;

/** WeChat code verification and independent, revocable mini-program sessions. */
@RestController
@RequestMapping("/auth")
public class LechengAuthController {
    private static final int ACCESS_SECONDS = 3600;
    private static final int REFRESH_SECONDS = 30 * 24 * 3600;
    private final JdbcTemplate jdbc;
    private final RestTemplate http;
    private final SecureRandom random = new SecureRandom();

    @Value("${lecheng.wechat.app-id:}") private String appId;
    @Value("${lecheng.wechat.app-secret:}") private String appSecret;
    @Value("${lecheng.wechat.api-base:https://api.weixin.qq.com}") private String apiBase;

    public LechengAuthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5000);
        factory.setReadTimeout(8000);
        this.http = new RestTemplate(factory);
    }

    @PostMapping("/wechat")
    public Map<String, Object> wechat(@RequestBody Map<String, String> input) {
        return login(input, false);
    }

    @PostMapping("/phone")
    public Map<String, Object> phone(@RequestBody Map<String, String> input) {
        return login(input, true);
    }

    private Map<String, Object> login(Map<String, String> input, boolean requirePhone) {
        configured();
        String code = required(input.get("code"), "微信登录凭证");
        String url = UriComponentsBuilder.fromHttpUrl(apiBase + "/sns/jscode2session")
            .queryParam("appid", appId).queryParam("secret", appSecret)
            .queryParam("js_code", code).queryParam("grant_type", "authorization_code")
            .build().encode().toUriString();
        Map<?, ?> identity = getWechat(url);
        if (identity == null) throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "微信认证服务返回空响应");
        String openid = identity.get("openid") instanceof String ? (String) identity.get("openid") : "";
        if (openid.isEmpty() || identity.containsKey("errcode")) throw unauthorized("微信登录凭证无效或已过期");
        String phoneNumber = "";
        if (requirePhone) phoneNumber = resolvePhone(required(input.get("phoneCode"), "手机号授权凭证"));
        jdbc.update("INSERT INTO lc_account(openid,phone) VALUES (?,?) ON DUPLICATE KEY UPDATE "
            + (requirePhone ? "phone=VALUES(phone)" : "openid=VALUES(openid)"), openid, phoneNumber);
        Long accountId = jdbc.queryForObject("SELECT id FROM lc_account WHERE openid=?", Long.class, openid);
        return issue(accountId);
    }

    private String resolvePhone(String phoneCode) {
        String tokenUrl = UriComponentsBuilder.fromHttpUrl(apiBase + "/cgi-bin/token")
            .queryParam("grant_type", "client_credential").queryParam("appid", appId)
            .queryParam("secret", appSecret).build().encode().toUriString();
        Map<?, ?> token = getWechat(tokenUrl);
        String accessToken = token.get("access_token") instanceof String ? (String) token.get("access_token") : "";
        if (accessToken.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "微信手机号服务暂不可用");
        String url = UriComponentsBuilder.fromHttpUrl(apiBase + "/wxa/business/getuserphonenumber")
            .queryParam("access_token", accessToken).build().encode().toUriString();
        try {
            ResponseEntity<Map> response = http.exchange(url, HttpMethod.POST,
                new HttpEntity<>(java.util.Collections.singletonMap("code", phoneCode)), Map.class);
            Map<?, ?> body = response.getBody();
            Object info = body == null ? null : body.get("phone_info");
            Object number = info instanceof Map ? ((Map<?, ?>) info).get("purePhoneNumber") : null;
            if (body == null || !Integer.valueOf(0).equals(asInt(body.get("errcode")))
                || !(number instanceof String) || !((String) number).matches("^1\\d{10}$"))
                throw unauthorized("手机号授权凭证无效或已过期");
            return (String) number;
        } catch (ResponseStatusException e) { throw e; }
        catch (Exception e) { throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "微信手机号服务暂不可用", e); }
    }

    private Map<?, ?> getWechat(String url) {
        try { return http.getForObject(url, Map.class); }
        catch (Exception e) { throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "微信认证服务暂不可用", e); }
    }

    private Integer asInt(Object value) {
        return value instanceof Number ? ((Number) value).intValue() : null;
    }

    @PostMapping("/refresh")
    @Transactional
    public Map<String, Object> refresh(@RequestBody Map<String, String> input) {
        String hash = hash(required(input.get("refreshToken"), "刷新凭证"));
        Long accountId = jdbc.query("SELECT account_id FROM lc_auth_session WHERE refresh_hash=? "
            + "AND revoked=0 AND refresh_expires_at>NOW() FOR UPDATE", rs -> rs.next() ? rs.getLong(1) : null, hash);
        if (accountId == null) throw unauthorized("登录状态已失效");
        jdbc.update("UPDATE lc_auth_session SET revoked=1 WHERE refresh_hash=?", hash);
        return issue(accountId);
    }

    @PostMapping("/logout")
    public Map<String, Object> logout(@RequestBody Map<String, String> input) {
        String value = input.get("refreshToken");
        if (value != null && !value.isEmpty())
            jdbc.update("UPDATE lc_auth_session SET revoked=1 WHERE refresh_hash=?", hash(value));
        return java.util.Collections.singletonMap("ok", true);
    }

    @GetMapping("/me")
    public Map<String, Object> me(@RequestHeader(value="X-Lecheng-Access", required=false) String token) {
        return user(accountForAccess(token));
    }

    @PutMapping("/me")
    public Map<String, Object> updateMe(@RequestHeader(value="X-Lecheng-Access", required=false) String token,
                                          @RequestBody Map<String, String> input) {
        Long accountId = accountForAccess(token);
        String name = required(input.get("name"), "昵称").trim();
        if (name.isEmpty() || name.length() > 50)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "昵称不能为空或超过 50 字");
        jdbc.update("UPDATE lc_account SET display_name=? WHERE id=?", name, accountId);
        return user(accountId);
    }

    private Long accountForAccess(String token) {
        if (token == null || token.isEmpty()) throw unauthorized("请先登录");
        String value = token;
        Long accountId = jdbc.query("SELECT account_id FROM lc_auth_session WHERE access_hash=? "
            + "AND revoked=0 AND access_expires_at>NOW()", rs -> rs.next() ? rs.getLong(1) : null, hash(value));
        if (accountId == null) throw unauthorized("登录状态已失效");
        return accountId;
    }

    private Map<String, Object> issue(Long accountId) {
        String access = token(), refresh = token();
        jdbc.update("INSERT INTO lc_auth_session(refresh_hash,access_hash,account_id,access_expires_at,refresh_expires_at) "
            + "VALUES (?,?,?,?,?)", hash(refresh), hash(access), accountId,
            LocalDateTime.now().plusSeconds(ACCESS_SECONDS), LocalDateTime.now().plusSeconds(REFRESH_SECONDS));
        Map<String, Object> result = new HashMap<>();
        result.put("accessToken", access);
        result.put("refreshToken", refresh);
        result.put("expiresIn", ACCESS_SECONDS);
        result.put("refreshExpiresIn", REFRESH_SECONDS);
        result.put("user", user(accountId));
        return result;
    }

    private Map<String, Object> user(Long accountId) {
        return jdbc.queryForMap("SELECT id,display_name AS name,phone FROM lc_account WHERE id=?", accountId);
    }

    private String token() {
        byte[] value = new byte[32]; random.nextBytes(value);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(value);
    }

    private String hash(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            StringBuilder out = new StringBuilder();
            for (byte b : digest) out.append(String.format("%02x", b & 0xff));
            return out.toString();
        } catch (Exception e) { throw new IllegalStateException(e); }
    }

    private String required(String value, String label) {
        if (value == null || value.isEmpty() || value.length() > 512)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, label + "不能为空或无效");
        return value;
    }

    private void configured() {
        if (appId == null || appId.isEmpty() || appSecret == null || appSecret.isEmpty())
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "微信登录尚未配置");
    }

    private ResponseStatusException unauthorized(String message) {
        return new ResponseStatusException(HttpStatus.UNAUTHORIZED, message);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, String>> authError(ResponseStatusException error) {
        return ResponseEntity.status(error.getStatus())
            .body(java.util.Collections.singletonMap("message", error.getReason()));
    }
}
