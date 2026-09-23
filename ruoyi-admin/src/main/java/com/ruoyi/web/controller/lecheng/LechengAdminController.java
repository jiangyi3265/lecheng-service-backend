package com.ruoyi.web.controller.lecheng;

import com.ruoyi.common.core.domain.AjaxResult;
import java.util.Map;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Authenticated RuoYi operator endpoints. */
@RestController
@RequestMapping("/lecheng")
public class LechengAdminController {
    private final LechengStore store;

    public LechengAdminController(LechengStore store) { this.store = store; }

    @PreAuthorize("@ss.hasPermi('lecheng:content:list')")
    @GetMapping("/content")
    public AjaxResult content(@RequestParam String kind) { return AjaxResult.success(store.content(kind, false)); }

    @PreAuthorize("@ss.hasPermi('lecheng:content:edit')")
    @PostMapping("/content")
    public AjaxResult saveContent(@RequestBody Map<String, Object> input) {
        store.saveContent(input);
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('lecheng:content:edit')")
    @DeleteMapping("/content/{id}")
    public AjaxResult deleteContent(@PathVariable String id) {
        return store.deleteContent(id) == 1 ? AjaxResult.success() : AjaxResult.error("内容不存在");
    }

    @PreAuthorize("@ss.hasPermi('lecheng:consult:list')")
    @GetMapping("/consultations")
    public AjaxResult consultations() { return AjaxResult.success(store.conversations()); }

    @PreAuthorize("@ss.hasPermi('lecheng:consult:list')")
    @GetMapping("/consultations/{sessionId}")
    public AjaxResult messages(@PathVariable String sessionId) { return AjaxResult.success(store.messages(sessionId)); }

    @PreAuthorize("@ss.hasPermi('lecheng:consult:reply')")
    @PostMapping("/consultations/{sessionId}/reply")
    public AjaxResult reply(@PathVariable String sessionId, @RequestBody Map<String, String> input) {
        return AjaxResult.success(store.addMessage(sessionId, "assistant", input.get("text")));
    }

    @PreAuthorize("@ss.hasPermi('lecheng:booking:list')")
    @GetMapping("/appointments")
    public AjaxResult appointments() { return AjaxResult.success(store.appointments(null)); }

    @PreAuthorize("@ss.hasPermi('lecheng:booking:edit')")
    @PutMapping("/appointments/{id}")
    public AjaxResult appointment(@PathVariable long id, @RequestBody Map<String, String> input) {
        return store.updateAppointment(null, id, input.get("status")) == 1
            ? AjaxResult.success() : AjaxResult.error("预约申请不存在");
    }

    @PreAuthorize("@ss.hasPermi('lecheng:feedback:list')")
    @GetMapping("/feedback")
    public AjaxResult feedback() { return AjaxResult.success(store.feedback(null)); }

    @PreAuthorize("@ss.hasPermi('lecheng:feedback:edit')")
    @PutMapping("/feedback/{id}")
    public AjaxResult feedback(@PathVariable long id, @RequestBody Map<String, String> input) {
        return store.updateFeedback(id, input.get("status")) == 1
            ? AjaxResult.success() : AjaxResult.error("反馈不存在");
    }
}
