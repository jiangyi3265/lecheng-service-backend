-- Lecheng business tables. Safe to run repeatedly; no existing RuoYi data is changed.
CREATE TABLE IF NOT EXISTS lc_content (
  id VARCHAR(80) NOT NULL PRIMARY KEY,
  kind VARCHAR(30) NOT NULL,
  title VARCHAR(200) NOT NULL,
  payload LONGTEXT NOT NULL,
  status CHAR(1) NOT NULL DEFAULT '1',
  sort_order INT NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_lc_content_kind (kind, status, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS lc_client (
  session_hash CHAR(64) NOT NULL PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS lc_message (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  session_hash CHAR(64) NOT NULL,
  sender VARCHAR(16) NOT NULL,
  body VARCHAR(1000) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_lc_message_thread (session_hash, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS lc_appointment (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  session_hash CHAR(64) NOT NULL,
  data_json LONGTEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT '待处理',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_lc_appointment_client (session_hash, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS lc_feedback (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  session_hash CHAR(64) NOT NULL,
  body VARCHAR(2000) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT '待处理',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_lc_feedback_client (session_hash, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS lc_account (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  openid VARCHAR(128) NOT NULL UNIQUE,
  display_name VARCHAR(50) NOT NULL DEFAULT '乐城用户',
  phone VARCHAR(20) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS lc_auth_session (
  refresh_hash CHAR(64) NOT NULL PRIMARY KEY,
  access_hash CHAR(64) NOT NULL UNIQUE,
  account_id BIGINT NOT NULL,
  access_expires_at DATETIME NOT NULL,
  refresh_expires_at DATETIME NOT NULL,
  revoked TINYINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_lc_auth_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One operations entry with independently assignable permissions for non-super-admin operators.
INSERT IGNORE INTO sys_menu(menu_id,menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time,remark)
VALUES (990001,'乐城运营',0,20,'lecheng','lecheng/index','Lecheng',1,0,'C','0','0','lecheng:content:list','guide','admin',NOW(),'乐城内容、咨询、预约申请与反馈');
INSERT IGNORE INTO sys_menu(menu_id,menu_name,parent_id,order_num,path,component,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time) VALUES
(990002,'内容查看',990001,1,'',NULL,1,0,'F','0','0','lecheng:content:list','#','admin',NOW()),
(990003,'内容编辑',990001,2,'',NULL,1,0,'F','0','0','lecheng:content:edit','#','admin',NOW()),
(990004,'咨询查看',990001,3,'',NULL,1,0,'F','0','0','lecheng:consult:list','#','admin',NOW()),
(990005,'咨询回复',990001,4,'',NULL,1,0,'F','0','0','lecheng:consult:reply','#','admin',NOW()),
(990006,'预约查看',990001,5,'',NULL,1,0,'F','0','0','lecheng:booking:list','#','admin',NOW()),
(990007,'预约处理',990001,6,'',NULL,1,0,'F','0','0','lecheng:booking:edit','#','admin',NOW()),
(990008,'反馈查看',990001,7,'',NULL,1,0,'F','0','0','lecheng:feedback:list','#','admin',NOW()),
(990009,'反馈处理',990001,8,'',NULL,1,0,'F','0','0','lecheng:feedback:edit','#','admin',NOW());
