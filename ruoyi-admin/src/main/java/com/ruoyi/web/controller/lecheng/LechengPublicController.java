package com.ruoyi.web.controller.lecheng;

import com.ruoyi.common.core.domain.AjaxResult;
import java.util.Collections;
import java.util.Map;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Mini-program API: content is public; personal records require an opaque guest session. */
@RestController
@RequestMapping("/open/lecheng")
public class LechengPublicController {
    private final LechengStore store;

    public LechengPublicController(LechengStore store) { this.store = store; }

    @GetMapping("/content/{kind}")
    public AjaxResult content(@PathVariable String kind) { return AjaxResult.success(store.content(kind, true)); }

    @PostMapping("/session")
    public AjaxResult session() { return AjaxResult.success(Collections.singletonMap("token", store.createSession())); }

    @GetMapping("/messages")
    public AjaxResult messages(@RequestHeader("X-Lecheng-Session") String token) {
        return AjaxResult.success(store.messages(store.requireSession(token)));
    }

    @PostMapping("/messages")
    public AjaxResult message(@RequestHeader("X-Lecheng-Session") String token, @RequestBody Map<String, String> input) {
        return AjaxResult.success(store.addMessage(store.requireSession(token), "user", input.get("text")));
    }

    @GetMapping("/appointments")
    public AjaxResult appointments(@RequestHeader("X-Lecheng-Session") String token) {
        return AjaxResult.success(store.appointments(store.requireSession(token)));
    }

    @PostMapping("/appointments")
    public AjaxResult appointment(@RequestHeader("X-Lecheng-Session") String token, @RequestBody Map<String, Object> input) {
        return AjaxResult.success(store.createAppointment(store.requireSession(token), input));
    }

    @DeleteMapping("/appointments/{id}")
    public AjaxResult cancel(@RequestHeader("X-Lecheng-Session") String token, @PathVariable long id) {
        return store.updateAppointment(store.requireSession(token), id, "已取消") == 1
            ? AjaxResult.success() : AjaxResult.error("预约申请不存在或已处理");
    }

    @GetMapping("/feedback")
    public AjaxResult feedback(@RequestHeader("X-Lecheng-Session") String token) {
        return AjaxResult.success(store.feedback(store.requireSession(token)));
    }

    @PostMapping("/feedback")
    public AjaxResult feedback(@RequestHeader("X-Lecheng-Session") String token, @RequestBody Map<String, String> input) {
        return AjaxResult.success(store.addFeedback(store.requireSession(token), input.get("text")));
    }
}
