-- 乐城后台：新增 首页轮播 / 福利活动 / 服务流程 / 园区导航 四个一级菜单（2026-10-16）
-- 都指向同一页面 lecheng/index，页面按地址最后一段（banner / benefit / process / park-guide）打开对应栏目。
-- 菜单编号 990022–990025，path 与 route_name 全库唯一；可重复执行（INSERT IGNORE，排序用 UPDATE）。
-- 左侧顺序：首页轮播 1、医院管理 2、批复项目 3、特许药械 4、亚健康项目 5、乐城动态 6、国家政策 7、了解乐城 8、
--           医生管理 9、福利活动 10、服务流程 11、园区导航 12、客服咨询 13、客服设置 14、预约申请 15、用户反馈 16。
-- 注意：lecheng_admin_menus_20261015.sql 会把顺序改回它自己的 12 项顺序；若重跑了它，之后要再跑一次本文件。

SET NAMES utf8mb4;

START TRANSACTION;

INSERT IGNORE INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
  is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, remark) VALUES
(990022, '首页轮播', 0, 1,  'banner',     'lecheng/index', NULL, 'LechengBanner',    1, 0, 'C', '0', '0', 'lecheng:content:list', 'slider',   'admin', NOW(), '小程序首页顶部大图轮播'),
(990023, '福利活动', 0, 10, 'benefit',    'lecheng/index', NULL, 'LechengBenefit',   1, 0, 'C', '0', '0', 'lecheng:content:list', 'shopping', 'admin', NOW(), '我的-福利活动'),
(990024, '服务流程', 0, 11, 'process',    'lecheng/index', NULL, 'LechengProcess',   1, 0, 'C', '0', '0', 'lecheng:content:list', 'list',     'admin', NOW(), '我的-服务流程'),
(990025, '园区导航', 0, 12, 'park-guide', 'lecheng/index', NULL, 'LechengParkGuide', 1, 0, 'C', '0', '0', 'lecheng:content:edit', 'guide',    'admin', NOW(), '我的-园区导航的地图位置和说明');

UPDATE sys_menu SET order_num = 2,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990010 AND order_num <> 2;
UPDATE sys_menu SET order_num = 3,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990011 AND order_num <> 3;
UPDATE sys_menu SET order_num = 4,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990012 AND order_num <> 4;
UPDATE sys_menu SET order_num = 5,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990013 AND order_num <> 5;
UPDATE sys_menu SET order_num = 6,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990014 AND order_num <> 6;
UPDATE sys_menu SET order_num = 7,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990019 AND order_num <> 7;
UPDATE sys_menu SET order_num = 8,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990020 AND order_num <> 8;
UPDATE sys_menu SET order_num = 9,  update_by = 'admin', update_time = NOW() WHERE menu_id = 990015 AND order_num <> 9;
UPDATE sys_menu SET order_num = 13, update_by = 'admin', update_time = NOW() WHERE menu_id = 990016 AND order_num <> 13;
UPDATE sys_menu SET order_num = 14, update_by = 'admin', update_time = NOW() WHERE menu_id = 990021 AND order_num <> 14;
UPDATE sys_menu SET order_num = 15, update_by = 'admin', update_time = NOW() WHERE menu_id = 990017 AND order_num <> 15;
UPDATE sys_menu SET order_num = 16, update_by = 'admin', update_time = NOW() WHERE menu_id = 990018 AND order_num <> 16;

-- 已分配了乐城菜单的角色（超级管理员不需要）：
-- 首页轮播 / 福利活动 / 服务流程（内容栏目）给能看到内容栏目 990010–990015、国家政策 990019、了解乐城 990020 的角色；
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT role_id, 990022 FROM sys_role_menu WHERE menu_id BETWEEN 990010 AND 990015 OR menu_id IN (990019, 990020);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT role_id, 990023 FROM sys_role_menu WHERE menu_id BETWEEN 990010 AND 990015 OR menu_id IN (990019, 990020);
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT role_id, 990024 FROM sys_role_menu WHERE menu_id BETWEEN 990010 AND 990015 OR menu_id IN (990019, 990020);
-- 园区导航的菜单权限是 lecheng:content:edit（与客服设置相同），只给本来就有内容编辑权限的角色，
-- 避免只做客服回复的角色顺带拿到编辑权限。
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT rm.role_id, 990025 FROM sys_role_menu rm
WHERE rm.menu_id BETWEEN 990010 AND 990021
  AND EXISTS (SELECT 1 FROM sys_role_menu e JOIN sys_menu m ON m.menu_id = e.menu_id
              WHERE e.role_id = rm.role_id AND m.perms = 'lecheng:content:edit' AND m.status = '0');

COMMIT;

-- 回滚（恢复 2026-10-15 的左侧顺序）：
-- DELETE FROM sys_role_menu WHERE menu_id BETWEEN 990022 AND 990025;
-- DELETE FROM sys_menu WHERE menu_id BETWEEN 990022 AND 990025;
-- UPDATE sys_menu SET order_num = 1  WHERE menu_id = 990010;
-- UPDATE sys_menu SET order_num = 2  WHERE menu_id = 990011;
-- UPDATE sys_menu SET order_num = 3  WHERE menu_id = 990012;
-- UPDATE sys_menu SET order_num = 4  WHERE menu_id = 990013;
-- UPDATE sys_menu SET order_num = 5  WHERE menu_id = 990014;
-- UPDATE sys_menu SET order_num = 6  WHERE menu_id = 990019;
-- UPDATE sys_menu SET order_num = 7  WHERE menu_id = 990020;
-- UPDATE sys_menu SET order_num = 8  WHERE menu_id = 990015;
-- UPDATE sys_menu SET order_num = 9  WHERE menu_id = 990016;
-- UPDATE sys_menu SET order_num = 10 WHERE menu_id = 990021;
-- UPDATE sys_menu SET order_num = 11 WHERE menu_id = 990017;
-- UPDATE sys_menu SET order_num = 12 WHERE menu_id = 990018;
