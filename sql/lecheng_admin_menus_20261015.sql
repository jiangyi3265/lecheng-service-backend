-- 乐城后台：新增 国家政策 / 了解乐城 / 客服设置 三个一级菜单（2026-10-15）
-- 都指向同一页面 lecheng/index，页面按地址最后一段（policy / about / support-settings）打开对应栏目。
-- 菜单编号 990019–990021，path 与 route_name 全库唯一；可重复执行（INSERT IGNORE，排序用 UPDATE）。
-- 左侧顺序：医院管理 1、批复项目 2、特许药械 3、亚健康项目 4、乐城动态 5、国家政策 6、了解乐城 7、
--           医生管理 8、客服咨询 9、客服设置 10、预约申请 11、用户反馈 12。

SET NAMES utf8mb4;

START TRANSACTION;

INSERT IGNORE INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
  is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
(990019, '国家政策', 0, 6,  'policy',           'lecheng/index', NULL, 'LechengPolicy',          1, 0, 'C', '0', '0', 'lecheng:content:list', 'form',          'admin', NOW(), '首页乐城介绍-国家政策'),
(990020, '了解乐城', 0, 7,  'about',            'lecheng/index', NULL, 'LechengAbout',           1, 0, 'C', '0', '0', 'lecheng:content:list', 'international', 'admin', NOW(), '首页乐城介绍-了解乐城'),
(990021, '客服设置', 0, 10, 'support-settings', 'lecheng/index', NULL, 'LechengSupportSettings', 1, 0, 'C', '0', '0', 'lecheng:content:edit', 'phone',         'admin', NOW(), '小程序客服页头像、开场白和在线时间');

UPDATE sys_menu SET order_num = 8,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990015 AND order_num <> 8;
UPDATE sys_menu SET order_num = 9,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990016 AND order_num <> 9;
UPDATE sys_menu SET order_num = 11, update_by = 'admin', update_time = NOW() WHERE menu_id = 990017 AND order_num <> 11;
UPDATE sys_menu SET order_num = 12, update_by = 'admin', update_time = NOW() WHERE menu_id = 990018 AND order_num <> 12;

-- 已分配了乐城菜单的角色（超级管理员不需要）：
-- 国家政策 / 了解乐城（只查看内容）给能看到内容栏目 990010–990015 的角色；
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT role_id, 990019 FROM sys_role_menu WHERE menu_id BETWEEN 990010 AND 990015;
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT role_id, 990020 FROM sys_role_menu WHERE menu_id BETWEEN 990010 AND 990015;
-- 客服设置的菜单权限是 lecheng:content:edit，只给本来就有内容编辑权限的角色，避免只做客服回复的角色顺带拿到编辑权限。
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT rm.role_id, 990021 FROM sys_role_menu rm
WHERE rm.menu_id BETWEEN 990010 AND 990018
  AND EXISTS (SELECT 1 FROM sys_role_menu e JOIN sys_menu m ON m.menu_id = e.menu_id
              WHERE e.role_id = rm.role_id AND m.perms = 'lecheng:content:edit' AND m.status = '0');

COMMIT;

-- 回滚：
-- DELETE FROM sys_role_menu WHERE menu_id BETWEEN 990019 AND 990021;
-- DELETE FROM sys_menu WHERE menu_id BETWEEN 990019 AND 990021;
-- UPDATE sys_menu SET order_num = 6 WHERE menu_id = 990015;
-- UPDATE sys_menu SET order_num = 7 WHERE menu_id = 990016;
-- UPDATE sys_menu SET order_num = 8 WHERE menu_id = 990017;
-- UPDATE sys_menu SET order_num = 9 WHERE menu_id = 990018;
