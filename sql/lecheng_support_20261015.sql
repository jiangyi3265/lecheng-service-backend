SET NAMES utf8mb4;

-- 乐城：客服未读提醒 + 客服设置 + 国家政策 / 了解乐城 改为后台维护（2026-10-15）
-- 可重复执行：建表用 IF NOT EXISTS，种子数据用 INSERT IGNORE，不会覆盖后台已修改的内容。
-- 回滚见文件末尾。

-- 已读位置：user_read_id = 小程序用户看到的最后一条消息编号，admin_read_id = 后台看到的最后一条消息编号。
CREATE TABLE IF NOT EXISTS lc_consult_read (
  session_hash CHAR(64) NOT NULL PRIMARY KEY,
  user_read_id BIGINT NOT NULL DEFAULT 0,
  admin_read_id BIGINT NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 若 lc_message 是在另一种默认排序规则下建的表，让 session_hash 的排序规则与它一致，避免两表关联时报 “Illegal mix of collations”。
SET @lc_msg_charset := (SELECT CHARACTER_SET_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lc_message' AND COLUMN_NAME = 'session_hash');
SET @lc_msg_collation := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lc_message' AND COLUMN_NAME = 'session_hash');
SET @lc_read_collation := (SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lc_consult_read' AND COLUMN_NAME = 'session_hash');
SET @lc_align_sql := IF(@lc_msg_collation IS NULL OR @lc_msg_collation = @lc_read_collation, 'DO 0',
  CONCAT('ALTER TABLE lc_consult_read MODIFY session_hash CHAR(64) CHARACTER SET ', @lc_msg_charset,
         ' COLLATE ', @lc_msg_collation, ' NOT NULL'));
PREPARE lc_align FROM @lc_align_sql;
EXECUTE lc_align;
DEALLOCATE PREPARE lc_align;

-- 上线前已有的会话全部算作已读（双方都不会冒出历史未读）。
-- 只在已读表还是空表时执行一次：上线后再重复执行本文件，不会把新的未读消息改成已读。
INSERT IGNORE INTO lc_consult_read(session_hash, user_read_id, admin_read_id)
SELECT session_hash, MAX(id), MAX(id) FROM lc_message
WHERE NOT EXISTS (SELECT 1 FROM lc_consult_read)
GROUP BY session_hash;

-- 客服设置（小程序客服页的头像、顶部标题、开场白、在线时间；头像为空 = 用小程序自带默认头像）
INSERT IGNORE INTO lc_content(id, kind, title, payload, status, sort_order) VALUES
('support-settings', 'support', '客服设置',
 '{"id":"support-settings","kindCode":"support","name":"客服设置","avatar":"","caption":"乐城服务为您服务","greeting":"您好：我是人工客服，我可以为您提供博鳌乐城：项目介绍、预约评估、陪诊服务咨询、预约流程相关信息。","hours":"人工在线时间：早8：00-晚22：00","status":"1","sortOrder":0,"contentVersion":2}',
 '1', 0);

-- 国家政策（原小程序 data/policies.js 里写死的 2 条）
INSERT IGNORE INTO lc_content(id, kind, title, payload, status, sort_order) VALUES
('policy-development-2019', 'policy', '支持建设乐城先行区',
 '{"id":"policy-development-2019","kindCode":"policy","title":"支持建设乐城先行区","fullTitle":"关于印发《关于支持建设博鳌乐城国际医疗旅游先行区的实施方案》的通知","date":"2019-09-10","tags":["建设发展","政策文件"],"summary":"先行区建设实施方案与部门协同安排。","coverImage":"","scene":0,"sourceName":"国家发展和改革委员会","sourceUrl":"https://www.ndrc.gov.cn/xxgk/zcfb/tz/201909/t20190916_1181919.html","paragraphs":["文件编号：发改地区〔2019〕1482号。由国家发展改革委、国家卫生健康委、国家中医药局、国家药监局联合印发。","该通知部署先行区建设工作，明确海南省主体责任、有关部门指导以及实施情况跟踪评估安排。"],"contentBlocks":[{"type":"text","title":"","text":"文件编号：发改地区〔2019〕1482号。由国家发展改革委、国家卫生健康委、国家中医药局、国家药监局联合印发。"},{"type":"text","title":"","text":"该通知部署先行区建设工作，明确海南省主体责任、有关部门指导以及实施情况跟踪评估安排。"}],"status":"1","sortOrder":0,"contentVersion":2}',
 '1', 0),
('policy-device-2018', 'policy', '临床急需医疗器械政策',
 '{"id":"policy-device-2018","kindCode":"policy","title":"临床急需医疗器械政策","fullTitle":"国务院关于在海南博鳌乐城国际医疗旅游先行区暂停实施《医疗器械监督管理条例》有关规定的决定","date":"2018-04-02","tags":["医疗器械","政策文件"],"summary":"先行区医疗器械相关规定的调整决定。","coverImage":"","scene":2,"sourceName":"商务部转载国务院文件","sourceUrl":"https://www.mofcom.gov.cn/zcfb/zgdwjjmywg/art/2018/art_662566da1a694f1d9ae10cb17261750f.html","paragraphs":["文件编号：国发〔2018〕10号。发布机关为国务院，成文日期为2018年4月2日。","该决定涉及先行区临床急需进口医疗器械的批准与使用管理，以及海南省有关监管职责。"],"contentBlocks":[{"type":"text","title":"","text":"文件编号：国发〔2018〕10号。发布机关为国务院，成文日期为2018年4月2日。"},{"type":"text","title":"","text":"该决定涉及先行区临床急需进口医疗器械的批准与使用管理，以及海南省有关监管职责。"}],"status":"1","sortOrder":1,"contentVersion":2}',
 '1', 1);

-- 了解乐城（原小程序 components/LechengIntro.vue 里写死的 3 段）
INSERT IGNORE INTO lc_content(id, kind, title, payload, status, sort_order) VALUES
('about-1', 'about', '走进乐城，了解身边的医疗资源',
 '{"id":"about-1","kindCode":"about","title":"走进乐城，了解身边的医疗资源","caption":"园区风貌 · 示意配图","coverImage":"","scene":3,"paragraphs":["从医疗资源到园区生活，认识乐城，可以从一所医院、一段行程开始。在这里，我们将医院信息、就医服务与园区动态放在一起，让每一位来访者在出发之前，对乐城多一份了解。","浏览医院介绍，了解科室与服务特色；阅读园区动态，关注生活与服务资讯。无论是为自己做准备，还是陪伴家人出行，都可以从这些信息开始规划。"],"contentBlocks":[{"type":"text","title":"","text":"从医疗资源到园区生活，认识乐城，可以从一所医院、一段行程开始。在这里，我们将医院信息、就医服务与园区动态放在一起，让每一位来访者在出发之前，对乐城多一份了解。"},{"type":"text","title":"","text":"浏览医院介绍，了解科室与服务特色；阅读园区动态，关注生活与服务资讯。无论是为自己做准备，还是陪伴家人出行，都可以从这些信息开始规划。"}],"status":"1","sortOrder":0,"contentVersion":2}',
 '1', 0),
('about-2', 'about', '了解就医服务，从容安排行程',
 '{"id":"about-2","kindCode":"about","title":"了解就医服务，从容安排行程","caption":"医疗建筑 · 示意配图","coverImage":"","scene":0,"paragraphs":["就医之前，先了解意向医院的科室设置、接诊安排和资料要求，可以让行程准备更有条理。将需要咨询的问题、既往就诊资料和出行安排提前整理，也方便与医院进一步沟通。","您可以在医院介绍中浏览相关信息，收藏关注的医院，方便再次查找。具体接诊时间、预约要求与服务安排，请通过医院官方渠道确认。"],"contentBlocks":[{"type":"text","title":"","text":"就医之前，先了解意向医院的科室设置、接诊安排和资料要求，可以让行程准备更有条理。将需要咨询的问题、既往就诊资料和出行安排提前整理，也方便与医院进一步沟通。"},{"type":"text","title":"","text":"您可以在医院介绍中浏览相关信息，收藏关注的医院，方便再次查找。具体接诊时间、预约要求与服务安排，请通过医院官方渠道确认。"}],"status":"1","sortOrder":1,"contentVersion":2}',
 '1', 1),
('about-3', 'about', '发现园区生活中的片刻闲适',
 '{"id":"about-3","kindCode":"about","title":"发现园区生活中的片刻闲适","caption":"园区绿意 · 示意配图","coverImage":"","scene":2,"paragraphs":["了解乐城，也是在了解一段行程中的日常。除了医院与就医服务，园区环境、交通和休憩安排，同样是出行前可以关注的内容。给行程留出适当余量，让每一步更加从容。","在乐城动态中，您可以继续阅读园区生活与服务资讯；在国家政策中，可以查看相关政策文件与来源，逐步认识乐城的更多方面。"],"contentBlocks":[{"type":"text","title":"","text":"了解乐城，也是在了解一段行程中的日常。除了医院与就医服务，园区环境、交通和休憩安排，同样是出行前可以关注的内容。给行程留出适当余量，让每一步更加从容。"},{"type":"text","title":"","text":"在乐城动态中，您可以继续阅读园区生活与服务资讯；在国家政策中，可以查看相关政策文件与来源，逐步认识乐城的更多方面。"}],"status":"1","sortOrder":2,"contentVersion":2}',
 '1', 2);

-- 回滚（会丢掉后台在这三类里做的修改和全部已读记录）：
-- DELETE FROM lc_content WHERE kind IN ('support', 'policy', 'about');
-- DROP TABLE IF EXISTS lc_consult_read;
