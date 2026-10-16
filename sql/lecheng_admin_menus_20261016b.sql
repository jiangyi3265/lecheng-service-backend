-- 乐城后台：新增一级菜单“联系方式”（2026-10-16）
-- 小程序“我的”页下方的客服在线时间、地址、电话。数据仍存在客服设置那条记录里，只是单独给一个入口；
-- “客服设置”菜单从此只显示客服页的头像、开场白等。菜单编号 990026，path/route_name 全库唯一；可重复执行。
-- 左侧顺序：…客服咨询 13、客服设置 14、联系方式 15、预约申请 16、用户反馈 17。

SET NAMES utf8mb4;

START TRANSACTION;

INSERT IGNORE INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
  is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
(990026, '联系方式', 0, 15, 'contact', 'lecheng/index', NULL, 'LechengContact', 1, 0, 'C', '0', '0', 'lecheng:content:edit', 'phone', 'admin', NOW(), '小程序我的页客服在线时间、地址、电话');

UPDATE sys_menu SET icon = 'user', update_by = 'admin', update_time = NOW() WHERE menu_id = 990021 AND icon <> 'user';
UPDATE sys_menu SET order_num = 16, update_by = 'admin', update_time = NOW() WHERE menu_id = 990017 AND order_num <> 16;
UPDATE sys_menu SET order_num = 17, update_by = 'admin', update_time = NOW() WHERE menu_id = 990018 AND order_num <> 17;

-- 已分配了“客服设置”的角色同样分配“联系方式”（同一权限 lecheng:content:edit）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT role_id, 990026 FROM sys_role_menu WHERE menu_id = 990021;

COMMIT;

-- 回滚：
-- DELETE FROM sys_role_menu WHERE menu_id = 990026;
-- DELETE FROM sys_menu WHERE menu_id = 990026;
-- UPDATE sys_menu SET icon = 'phone' WHERE menu_id = 990021;
-- UPDATE sys_menu SET order_num = 15 WHERE menu_id = 990017;
-- UPDATE sys_menu SET order_num = 16 WHERE menu_id = 990018;
