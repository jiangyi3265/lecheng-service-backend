SET NAMES utf8mb4;

-- 乐城：首页轮播 / 福利活动 / 服务流程 / 园区导航 改为后台维护（2026-10-16）
-- 可重复执行：种子数据用 INSERT IGNORE，不会覆盖后台已修改的内容（注意：后台删掉的预置条目，重跑本文件会重新插入）。
-- 客服设置（support-settings）新增的“我的”页联系方式字段 contactHours / contactAddress / contactPhone 都是选填，
-- 这里不改那一行：没填时小程序继续显示自带的默认值（电话为空显示“待更新”）。
-- 回滚见文件末尾。

-- 首页轮播（原小程序 pages/index/index.vue 里写死的 2 张；coverImage 为空 = 显示 scene 对应的默认插画）
INSERT IGNORE INTO lc_content(id, kind, title, payload, status, sort_order) VALUES
('banner-1', 'banner', '走进乐城',
 '{"id":"banner-1","kindCode":"banner","title":"走进乐城","subtitle":"发现身边的优质医疗","coverImage":"","scene":0,"status":"1","sortOrder":0,"contentVersion":2}',
 '1', 0),
('banner-2', 'banner', '你好，乐城',
 '{"id":"banner-2","kindCode":"banner","title":"你好，乐城","subtitle":"让优质医疗，更近一步","coverImage":"","scene":3,"status":"1","sortOrder":1,"contentVersion":2}',
 '1', 1);

-- 福利活动：目前没有已发布的活动，不预置（小程序显示“暂无福利活动”）。

-- 服务流程（原小程序 data/service-articles.js 里写死的 3 条；列表摘要 = 正文第一段）
INSERT IGNORE INTO lc_content(id, kind, title, payload, status, sort_order) VALUES
('find-care', 'process', '浏览与查询：找到需要的医疗信息',
 '{"id":"find-care","kindCode":"process","title":"浏览与查询：找到需要的医疗信息","summary":"从首页浏览医院介绍，或进入查询页面，按医院、药品、器械查找相关信息。","coverImage":"","scene":0,"paragraphs":["从首页浏览医院介绍，或进入查询页面，按医院、药品、器械查找相关信息。","打开条目可查看详情，感兴趣的医院、药械和资讯可以收藏，之后从“我的收藏”继续查看。"],"contentBlocks":[{"type":"text","title":"","text":"从首页浏览医院介绍，或进入查询页面，按医院、药品、器械查找相关信息。"},{"type":"text","title":"","text":"打开条目可查看详情，感兴趣的医院、药械和资讯可以收藏，之后从“我的收藏”继续查看。"}],"status":"1","sortOrder":0,"contentVersion":2}',
 '1', 0),
('consult', 'process', '在线咨询：在客服页面沟通',
 '{"id":"consult","kindCode":"process","title":"在线咨询：在客服页面沟通","summary":"点击底部“客服”入口，直接在输入框中填写问题。","coverImage":"","scene":1,"paragraphs":["点击底部“客服”入口，直接在输入框中填写问题。","连接后台后留言会同步给运营人员处理；目前不提供医生诊断或实时人工接诊承诺。"],"contentBlocks":[{"type":"text","title":"","text":"点击底部“客服”入口，直接在输入框中填写问题。"},{"type":"text","title":"","text":"连接后台后留言会同步给运营人员处理；目前不提供医生诊断或实时人工接诊承诺。"}],"status":"1","sortOrder":1,"contentVersion":2}',
 '1', 1),
('visit', 'process', '预约与出行：做好到院准备',
 '{"id":"visit","kindCode":"process","title":"预约与出行：做好到院准备","summary":"在医院详情中查看医疗环境，并使用“预约问诊”进入客服页面咨询。","coverImage":"","scene":3,"paragraphs":["在医院详情中查看医疗环境，并使用“预约问诊”进入客服页面咨询。","通过“园区导航”查看博鳌乐城地图，使用地图应用查找实际接诊医院并规划路线。出发前请通过医院官方渠道确认接诊安排。"],"contentBlocks":[{"type":"text","title":"","text":"在医院详情中查看医疗环境，并使用“预约问诊”进入客服页面咨询。"},{"type":"text","title":"","text":"通过“园区导航”查看博鳌乐城地图，使用地图应用查找实际接诊医院并规划路线。出发前请通过医院官方渠道确认接诊安排。"}],"status":"1","sortOrder":2,"contentVersion":2}',
 '1', 2);

-- 园区导航（单条设置；原小程序 data/park-map.js 与 pages/guide/guide.vue 里写死的值）
-- 坐标为 GCJ-02（微信 / 腾讯 / 高德地图使用），是园区综合服务中心的位置，不是医院入口。
INSERT IGNORE INTO lc_content(id, kind, title, payload, status, sort_order) VALUES
('park-guide', 'guide', '园区导航',
 '{"id":"park-guide","kindCode":"guide","name":"园区导航","title":"博鳌乐城国际医疗旅游先行区","address":"海南省琼海市博鳌镇","note":"地图标记为园区综合服务中心。前往医院，请在地图中确认具体院区与入口。","markerName":"乐城综合服务中心","latitude":19.149250,"longitude":110.498542,"status":"1","sortOrder":0,"contentVersion":2}',
 '1', 0);

-- 回滚（会丢掉后台在这四类里做的修改）：需与后端 jar 一起回滚，小程序才会全部退回自带的默认内容。
-- 只删数据而保留新后端时：首页轮播、园区导航退回默认，福利活动本来为空，但“服务流程”会显示“暂无服务流程”；
-- 若只是想恢复预置内容，删完后重新执行本文件即可（INSERT IGNORE 会补回预置条目）。
-- DELETE FROM lc_content WHERE kind IN ('banner', 'benefit', 'process', 'guide');
