package com.ruoyi.web.controller.lecheng;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Persistent Lecheng data. Guest session tokens are opaque and stored only as hashes. */
@Service
public class LechengStore {
    private static final Pattern PHONE = Pattern.compile("^1\\d{10}$");
    private static final Pattern SESSION_ID = Pattern.compile("^[0-9a-f]{64}$");
    private static final List<String> KINDS = Arrays.asList("hospital", "resource", "project", "news", "doctor", "policy", "about", "support");
    /** Kinds whose title field is "title"; all other kinds use "name". */
    private static final List<String> TITLE_KINDS = Arrays.asList("news", "policy", "about");
    /** The customer-service settings are a single record. */
    private static final String SUPPORT_ID = "support-settings";
    private static final String UPSERT_USER_READ = "INSERT INTO lc_consult_read(session_hash,user_read_id,admin_read_id) VALUES (?,?,0) "
        + "ON DUPLICATE KEY UPDATE user_read_id=GREATEST(user_read_id,?)";
    private static final String UPSERT_ADMIN_READ = "INSERT INTO lc_consult_read(session_hash,user_read_id,admin_read_id) VALUES (?,0,?) "
        + "ON DUPLICATE KEY UPDATE admin_read_id=GREATEST(admin_read_id,?)";
    private final JdbcTemplate jdbc;
    private final ObjectMapper json;
    private final SecureRandom random = new SecureRandom();

    public LechengStore(JdbcTemplate jdbc, ObjectMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    public String createSession() {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        jdbc.update("INSERT INTO lc_client(session_hash) VALUES (?)", hash(token));
        return token;
    }

    public String requireSession(String token) {
        if (token == null || token.length() != 43) throw new IllegalArgumentException("请重新打开小程序建立咨询会话");
        String session = hash(token);
        if (jdbc.queryForObject("SELECT COUNT(*) FROM lc_client WHERE session_hash=?", Integer.class, session) == 0)
            throw new IllegalArgumentException("咨询会话已失效，请重新打开小程序");
        jdbc.update("UPDATE lc_client SET last_seen_at=NOW() WHERE session_hash=?", session);
        return session;
    }

    private String hash(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder result = new StringBuilder(64);
            for (byte b : digest) result.append(String.format("%02x", b & 0xff));
            return result.toString();
        } catch (Exception e) { throw new IllegalStateException(e); }
    }

    public List<Map<String, Object>> content(String kind, boolean publicOnly) {
        if (!KINDS.contains(kind)) throw new IllegalArgumentException("未知内容分类");
        String sql = "SELECT id,kind,title,payload,status,sort_order FROM lc_content WHERE kind=?"
            + (publicOnly ? " AND status='1'" : "") + " ORDER BY sort_order,id";
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> row : jdbc.queryForList(sql, kind)) {
            Map<String, Object> entry = parse((String) row.get("payload"));
            entry.put("id", row.get("id"));
            entry.put("kindCode", row.get("kind"));
            if (!publicOnly) {
                entry.put("status", row.get("status"));
                entry.put("sortOrder", row.get("sort_order"));
            }
            result.add(entry);
        }
        return result;
    }

    public void saveContent(Map<String, Object> input) {
        String id = text(input.get("id"), 80, "内容 ID");
        String kind = text(input.get("kindCode"), 30, "分类");
        if (!KINDS.contains(kind)) throw new IllegalArgumentException("未知内容分类");
        if ("support".equals(kind) && !SUPPORT_ID.equals(id)) throw new IllegalArgumentException("客服设置编号无效");
        String title = text(input.get(TITLE_KINDS.contains(kind) ? "title" : "name"), 200, "标题");
        String status = "0".equals(input.get("status")) ? "0" : "1";
        int order = input.get("sortOrder") instanceof Number ? ((Number) input.get("sortOrder")).intValue() : 0;
        if (order < 0 || order > 100000) throw new IllegalArgumentException("排序值无效");
        input.put("id", id);
        input.put("status", status);
        input.put("sortOrder", order);
        if (!"support".equals(kind)) input.putIfAbsent("scene", 0);
        if ("hospital".equals(kind)) {
            input.putIfAbsent("tags", Collections.emptyList());
            input.putIfAbsent("departments", Collections.emptyList());
            input.putIfAbsent("features", Collections.emptyList());
            input.putIfAbsent("subtitle", "");
            input.putIfAbsent("description", "");
            input.putIfAbsent("address", "");
            input.putIfAbsent("type", "医院");
        }
        if ("project".equals(kind) || "resource".equals(kind)) {
            input.putIfAbsent("hospitalIds", Collections.emptyList());
            input.putIfAbsent("summary", "");
            input.putIfAbsent("category", "");
            input.putIfAbsent("spec", "");
            input.putIfAbsent("brand", "");
            input.putIfAbsent("kind", "project".equals(kind) ? "批复项目" : "药品");
        }
        if ("project".equals(kind)) input.putIfAbsent("departments", Collections.emptyList());
        if ("news".equals(kind)) {
            input.putIfAbsent("summary", "");
            input.putIfAbsent("paragraphs", Collections.emptyList());
            input.putIfAbsent("date", "");
        }
        if ("policy".equals(kind)) {
            input.putIfAbsent("tags", Collections.emptyList());
            input.putIfAbsent("summary", "");
            input.putIfAbsent("paragraphs", Collections.emptyList());
            input.putIfAbsent("date", "");
            input.putIfAbsent("fullTitle", "");
            input.putIfAbsent("sourceName", "");
            input.putIfAbsent("sourceUrl", "");
            input.putIfAbsent("coverImage", "");
        }
        if ("about".equals(kind)) {
            input.putIfAbsent("paragraphs", Collections.emptyList());
            input.putIfAbsent("caption", "");
            input.putIfAbsent("coverImage", "");
        }
        if ("support".equals(kind)) {
            // Empty values are allowed: the mini program then falls back to its bundled avatar and default texts.
            String avatar = optionalText(input.get("avatar"), 500, "客服头像");
            if (!avatar.isEmpty() && !avatar.startsWith("http://") && !avatar.startsWith("https://") && !avatar.startsWith("/"))
                throw new IllegalArgumentException("客服头像地址无效，请重新上传图片");
            input.put("avatar", avatar);
            input.put("caption", optionalText(input.get("caption"), 100, "顶部标题"));
            input.put("greeting", optionalText(input.get("greeting"), 500, "开场白"));
            input.put("hours", optionalText(input.get("hours"), 100, "在线时间"));
        }
        if ("doctor".equals(kind)) {
            String hospitalId = text(input.get("hospitalId"), 80, "所属医院 ID");
            List<Map<String, Object>> hospitals = jdbc.queryForList(
                "SELECT title FROM lc_content WHERE id=? AND kind='hospital' AND status='1'", hospitalId);
            if (hospitals.isEmpty()) throw new IllegalArgumentException("所属医院不存在或未上架");
            input.put("hospitalName", hospitals.get(0).get("title"));
            input.putIfAbsent("department", "待更新");
            input.putIfAbsent("intro", "");
            input.putIfAbsent("services", Collections.emptyList());
        }
        try {
            String payload = json.writeValueAsString(input);
            if (payload.length() > 100000) throw new IllegalArgumentException("内容过长");
            jdbc.update("INSERT INTO lc_content(id,kind,title,payload,status,sort_order) VALUES (?,?,?,?,?,?) "
                + "ON DUPLICATE KEY UPDATE kind=VALUES(kind),title=VALUES(title),payload=VALUES(payload),status=VALUES(status),sort_order=VALUES(sort_order)",
                id, kind, title, payload, status, order);
        } catch (JsonProcessingException e) { throw new IllegalArgumentException("内容格式无效"); }
    }

    public int deleteContent(String id) { return jdbc.update("DELETE FROM lc_content WHERE id=?", id); }

    public List<Map<String, Object>> messages(String session) {
        // 取最新的 500 条再按时间正序返回，长会话也能看到最新回复（未读标记才能清掉）
        return jdbc.queryForList("SELECT id,role,text,time FROM (SELECT id,sender AS role,body AS text,"
            + "UNIX_TIMESTAMP(created_at)*1000 AS time FROM lc_message WHERE session_hash=? ORDER BY id DESC LIMIT 500) newest ORDER BY id", session);
    }

    public Map<String, Object> addMessage(String session, String sender, String body) {
        String safe = text(body, 1000, "消息");
        KeyHolder key = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            java.sql.PreparedStatement statement = connection.prepareStatement(
                "INSERT INTO lc_message(session_hash,sender,body) VALUES (?,?,?)", java.sql.Statement.RETURN_GENERATED_KEYS);
            statement.setString(1, session);
            statement.setString(2, sender);
            statement.setString(3, safe);
            return statement;
        }, key);
        return jdbc.queryForMap("SELECT id,sender AS role,body AS text,UNIX_TIMESTAMP(created_at)*1000 AS time "
            + "FROM lc_message WHERE id=?", key.getKey().longValue());
    }

    /** Admin reply; replying counts as having read the conversation. */
    @Transactional
    public Map<String, Object> reply(String sessionId, String body) {
        requireConversation(sessionId);
        Map<String, Object> message = addMessage(sessionId, "assistant", body);
        long id = ((Number) message.get("id")).longValue();
        jdbc.update(UPSERT_ADMIN_READ, sessionId, id, id);
        return message;
    }

    /** Newest 200 conversations; unreadCount counts user messages after the operator's read pointer. */
    public List<Map<String, Object>> conversations() {
        return jdbc.queryForList("SELECT g.sessionId,g.lastId,l.body AS lastMessage,g.updatedAt,g.messageCount,g.unreadCount,l.sender AS lastRole "
            + "FROM (SELECT m.session_hash AS sessionId,MAX(m.id) AS lastId,MAX(m.created_at) AS updatedAt,COUNT(*) AS messageCount,"
            + "COUNT(CASE WHEN m.sender='user' AND m.id>COALESCE(r.admin_read_id,0) THEN 1 END) AS unreadCount "
            + "FROM lc_message m LEFT JOIN lc_consult_read r ON r.session_hash=m.session_hash "
            + "GROUP BY m.session_hash ORDER BY lastId DESC LIMIT 200) g "
            + "JOIN lc_message l ON l.id=g.lastId ORDER BY g.lastId DESC");
    }

    /** Operator-side totals: unread user messages and the number of conversations that have any. */
    public Map<String, Object> adminUnread() {
        Map<String, Object> row = jdbc.queryForMap("SELECT COUNT(*) AS unreadCount,COUNT(DISTINCT m.session_hash) AS sessionCount "
            + "FROM lc_message m LEFT JOIN lc_consult_read r ON r.session_hash=m.session_hash "
            + "WHERE m.sender='user' AND m.id>COALESCE(r.admin_read_id,0)");
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("count", number(row.get("unreadCount")));
        result.put("sessions", number(row.get("sessionCount")));
        return result;
    }

    /** Marks everything in the conversation as read by the operator; returns the new totals. */
    public Map<String, Object> markAdminRead(String sessionId) {
        long lastId = requireConversation(sessionId);
        jdbc.update(UPSERT_ADMIN_READ, sessionId, lastId, lastId);
        return adminUnread();
    }

    /** Mini-program side: operator replies newer than the guest's read pointer. */
    public Map<String, Object> userUnread(String session) {
        Map<String, Object> row = jdbc.queryForMap("SELECT COUNT(CASE WHEN m.id>COALESCE((SELECT r.user_read_id FROM lc_consult_read r "
            + "WHERE r.session_hash=?),0) THEN 1 END) AS unreadCount,COALESCE(MAX(m.id),0) AS maxId "
            + "FROM lc_message m WHERE m.session_hash=? AND m.sender='assistant'", session, session);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("count", number(row.get("unreadCount")));
        result.put("lastId", number(row.get("maxId")));
        return result;
    }

    /** Moves the guest's read pointer forward (never backward, never past the newest message). */
    public Map<String, Object> markUserRead(String session, Object lastIdInput) {
        long wanted = positiveId(lastIdInput);
        if (wanted > 0) {
            long target = Math.min(wanted, lastMessageId(session));
            if (target > 0) jdbc.update(UPSERT_USER_READ, session, target, target);
        }
        return userUnread(session);
    }

    private long requireConversation(String sessionId) {
        if (sessionId == null || !SESSION_ID.matcher(sessionId).matches()) throw new IllegalArgumentException("会话不存在");
        long lastId = lastMessageId(sessionId);
        if (lastId == 0) throw new IllegalArgumentException("会话不存在");
        return lastId;
    }

    private long lastMessageId(String session) {
        Long lastId = jdbc.queryForObject("SELECT COALESCE(MAX(id),0) FROM lc_message WHERE session_hash=?", Long.class, session);
        return lastId == null ? 0 : lastId;
    }

    private static long positiveId(Object value) {
        if (value instanceof String && ((String) value).trim().matches("\\d{1,18}")) return Long.parseLong(((String) value).trim());
        if (!(value instanceof Number)) return 0;
        double asDouble = ((Number) value).doubleValue();
        if (!(asDouble > 0)) return 0;
        return asDouble >= Long.MAX_VALUE ? Long.MAX_VALUE : ((Number) value).longValue();
    }

    private static long number(Object value) { return value instanceof Number ? ((Number) value).longValue() : 0; }

    public List<Map<String, Object>> appointments(String session) {
        List<Map<String, Object>> rows = session == null
            ? jdbc.queryForList("SELECT id,data_json,status,UNIX_TIMESTAMP(created_at)*1000 AS createdAt FROM lc_appointment ORDER BY id DESC LIMIT 500")
            : jdbc.queryForList("SELECT id,data_json,status,UNIX_TIMESTAMP(created_at)*1000 AS createdAt FROM lc_appointment WHERE session_hash=? ORDER BY id DESC LIMIT 100", session);
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Map<String, Object> item = parse((String) row.get("data_json"));
            item.put("id", "LC" + row.get("id"));
            item.put("status", row.get("status"));
            item.put("createdAt", row.get("createdAt"));
            result.add(item);
        }
        return result;
    }

    public Map<String, Object> createAppointment(String session, Map<String, Object> input) {
        text(input.get("name"), 50, "姓名");
        if (!PHONE.matcher(String.valueOf(input.getOrDefault("phone", ""))).matches())
            throw new IllegalArgumentException("请输入正确的手机号码");
        LocalDate date;
        try { date = LocalDate.parse(String.valueOf(input.get("date"))); }
        catch (Exception e) { throw new IllegalArgumentException("请选择有效日期"); }
        if (!date.isAfter(LocalDate.now()) || date.isAfter(LocalDate.now().plusDays(7)))
            throw new IllegalArgumentException("预约日期须在未来 7 天内");
        String slot = text(input.get("slot"), 40, "时段");
        if (!Arrays.asList("09:00–09:30", "10:00–10:30", "14:00–14:30", "15:00–15:30").contains(slot))
            throw new IllegalArgumentException("预约时段无效");
        String doctorId = text(input.get("doctorId"), 80, "医生");
        List<Map<String, Object>> doctors = jdbc.queryForList(
            "SELECT payload FROM lc_content WHERE kind='doctor' AND status='1' AND id=?", doctorId);
        if (doctors.isEmpty()) throw new IllegalArgumentException("所选医生暂不可预约");
        Map<String, Object> doctor = parse((String) doctors.get(0).get("payload"));
        input.put("doctorName", doctor.get("name"));
        input.put("hospitalId", doctor.get("hospitalId"));
        input.put("hospitalName", doctor.get("hospitalName"));
        input.put("department", doctor.get("department"));
        try {
            String payload = json.writeValueAsString(input);
            if (payload.length() > 4000) throw new IllegalArgumentException("预约内容过长");
            KeyHolder key = new GeneratedKeyHolder();
            jdbc.update(connection -> {
                java.sql.PreparedStatement statement = connection.prepareStatement(
                    "INSERT INTO lc_appointment(session_hash,data_json) VALUES (?,?)", java.sql.Statement.RETURN_GENERATED_KEYS);
                statement.setString(1, session);
                statement.setString(2, payload);
                return statement;
            }, key);
            Map<String, Object> result = parse(payload);
            result.put("id", "LC" + key.getKey().longValue());
            result.put("status", "待处理");
            return result;
        } catch (JsonProcessingException e) { throw new IllegalArgumentException("预约格式无效"); }
    }

    public int updateAppointment(String session, long id, String status) {
        if (!Arrays.asList("待处理", "已联系", "已取消").contains(status)) throw new IllegalArgumentException("状态无效");
        return session == null
            ? jdbc.update("UPDATE lc_appointment SET status=? WHERE id=?", status, id)
            : jdbc.update("UPDATE lc_appointment SET status='已取消' WHERE id=? AND session_hash=? AND status='待处理'", id, session);
    }

    public List<Map<String, Object>> feedback(String session) {
        return session == null
            ? jdbc.queryForList("SELECT id,body AS text,status,UNIX_TIMESTAMP(created_at)*1000 AS time FROM lc_feedback ORDER BY id DESC LIMIT 500")
            : jdbc.queryForList("SELECT id,body AS text,status,UNIX_TIMESTAMP(created_at)*1000 AS time FROM lc_feedback WHERE session_hash=? ORDER BY id DESC LIMIT 100", session);
    }

    public Map<String, Object> addFeedback(String session, String body) {
        String safe = text(body, 2000, "反馈");
        KeyHolder key = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            java.sql.PreparedStatement statement = connection.prepareStatement(
                "INSERT INTO lc_feedback(session_hash,body) VALUES (?,?)", java.sql.Statement.RETURN_GENERATED_KEYS);
            statement.setString(1, session);
            statement.setString(2, safe);
            return statement;
        }, key);
        return jdbc.queryForMap("SELECT id,body AS text,status,UNIX_TIMESTAMP(created_at)*1000 AS time FROM lc_feedback WHERE id=?", key.getKey().longValue());
    }

    public int updateFeedback(long id, String status) {
        if (!Arrays.asList("待处理", "已处理").contains(status)) throw new IllegalArgumentException("状态无效");
        return jdbc.update("UPDATE lc_feedback SET status=? WHERE id=?", status, id);
    }

    private Map<String, Object> parse(String value) {
        try { return json.readValue(value, new TypeReference<Map<String, Object>>() {}); }
        catch (Exception e) { throw new IllegalStateException("数据库内容 JSON 损坏", e); }
    }

    private String text(Object value, int max, String label) {
        String string = value instanceof String ? ((String) value).trim() : "";
        if (string.isEmpty() || string.length() > max) throw new IllegalArgumentException(label + "不能为空或超过 " + max + " 字");
        return string;
    }

    /** Like text(), but empty is allowed (null and missing become ""). */
    private String optionalText(Object value, int max, String label) {
        if (value == null) return "";
        if (!(value instanceof String)) throw new IllegalArgumentException(label + "格式无效");
        String string = ((String) value).trim();
        if (string.length() > max) throw new IllegalArgumentException(label + "不能超过 " + max + " 字");
        return string;
    }
}
