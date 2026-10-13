-- 乐城后台：左侧菜单展开为 9 个独立栏目（2026-10-13）
-- 原“乐城运营”(990001) 保留为隐藏菜单：旧地址 /lecheng 仍可打开，且仍是 990002–990009 按钮权限的父级。
-- 新栏目都指向同一页面 lecheng/index，页面按地址最后一段（hospital / project / …）打开对应栏目。
-- 菜单编号 990010–990018，path 与 route_name 全库唯一。

START TRANSACTION;

UPDATE sys_menu SET visible = '1', update_by = 'admin', update_time = NOW(),
  remark = '旧的合并页，左侧菜单已拆分为 990010-990018'
WHERE menu_id = 990001;

INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
  is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
(990010, '医院管理',   0, 1, 'hospital',      'lecheng/index', NULL, 'LechengHospital',      1, 0, 'C', '0', '0', 'lecheng:content:list',  'build',         'admin', NOW(), '小程序医院介绍'),
(990011, '批复项目',   0, 2, 'project',       'lecheng/index', NULL, 'LechengProject',       1, 0, 'C', '0', '0', 'lecheng:content:list',  'documentation', 'admin', NOW(), '查询页批复项目'),
(990012, '特许药械',   0, 3, 'medicine',      'lecheng/index', NULL, 'LechengMedicine',      1, 0, 'C', '0', '0', 'lecheng:content:list',  'clipboard',     'admin', NOW(), '查询页特许药械'),
(990013, '亚健康项目', 0, 4, 'wellness',      'lecheng/index', NULL, 'LechengWellness',      1, 0, 'C', '0', '0', 'lecheng:content:list',  'star',          'admin', NOW(), '查询页亚健康项目'),
(990014, '乐城动态',   0, 5, 'news',          'lecheng/index', NULL, 'LechengNews',          1, 0, 'C', '0', '0', 'lecheng:content:list',  'log',           'admin', NOW(), '首页乐城动态与动态页资讯'),
(990015, '医生管理',   0, 6, 'doctor',        'lecheng/index', NULL, 'LechengDoctor',        1, 0, 'C', '0', '0', 'lecheng:content:list',  'peoples',       'admin', NOW(), '科室与预约页医生资料'),
(990016, '客服咨询',   0, 7, 'consultations', 'lecheng/index', NULL, 'LechengConsultations', 1, 0, 'C', '0', '0', 'lecheng:consult:list',  'message',       'admin', NOW(), '小程序客服留言与回复'),
(990017, '预约申请',   0, 8, 'appointments',  'lecheng/index', NULL, 'LechengAppointments',  1, 0, 'C', '0', '0', 'lecheng:booking:list',  'date',          'admin', NOW(), '预约咨询申请'),
(990018, '用户反馈',   0, 9, 'feedback',      'lecheng/index', NULL, 'LechengFeedback',      1, 0, 'C', '0', '0', 'lecheng:feedback:list', 'edit',          'admin', NOW(), '用户意见反馈');

COMMIT;

-- 回滚：
-- DELETE FROM sys_menu WHERE menu_id BETWEEN 990010 AND 990018;
-- UPDATE sys_menu SET visible = '0', remark = '' WHERE menu_id = 990001;
