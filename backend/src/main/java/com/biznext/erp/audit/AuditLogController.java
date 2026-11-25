package com.biznext.erp.audit;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/audit")
public class AuditLogController {
    private final AuditLogService service;

    public AuditLogController(AuditLogService service) {
        this.service = service;
    }

    @GetMapping("/logs")
    public List<AuditLogResponse> getByBusiness(@RequestParam Long businessId) {
        return service.getByBusiness(businessId);
    }

    @GetMapping("/logs/user")
    public List<AuditLogResponse> getByUser(@RequestParam String userName) {
        return service.getByUser(userName);
    }

    @GetMapping("/logs/module")
    public List<AuditLogResponse> getByModule(@RequestParam String moduleName) {
        return service.getByModule(moduleName);
    }

    @GetMapping("/logs/date")
    public List<AuditLogResponse> getByDate(@RequestParam Long businessId,
                                           @RequestParam String from,
                                           @RequestParam String to) {
        return service.getByDate(businessId, LocalDateTime.parse(from), LocalDateTime.parse(to));
    }

    @PostMapping("/logs")
    public ResponseEntity<AuditLogResponse> create(@Valid @RequestBody AuditLogRequest request) {
        return ResponseEntity.ok(service.recordAudit(request));
    }
}
