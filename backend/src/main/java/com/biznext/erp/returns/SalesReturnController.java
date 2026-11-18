package com.biznext.erp.returns;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/sales")
public class SalesReturnController {
    private final SalesReturnService service;

    public SalesReturnController(SalesReturnService service) {
        this.service = service;
    }

    @GetMapping("/returns")
    public List<SalesReturnResponse> getAll(@RequestParam Long businessId) {
        return service.getByBusiness(businessId);
    }

    @PostMapping("/returns")
    public ResponseEntity<SalesReturnResponse> createReturn(@Valid @RequestBody SalesReturnRequest request) {
        return ResponseEntity.ok(service.createReturn(request));
    }

    @PostMapping("/returns/{id}/approve")
    public ResponseEntity<SalesReturnResponse> approve(@PathVariable Long id) {
        return ResponseEntity.ok(service.approveReturn(id));
    }

    @PostMapping("/returns/{id}/reject")
    public ResponseEntity<SalesReturnResponse> reject(@PathVariable Long id, @RequestParam(required = false) String reason) {
        return ResponseEntity.ok(service.rejectReturn(id, reason));
    }
}
