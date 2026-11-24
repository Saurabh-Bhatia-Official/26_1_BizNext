package com.biznext.erp.returns;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/purchases")
public class PurchaseReturnController {
    private final PurchaseReturnService service;

    public PurchaseReturnController(PurchaseReturnService service) {
        this.service = service;
    }

    @GetMapping("/returns")
    public List<PurchaseReturnResponse> getAll(@RequestParam Long businessId) {
        return service.getByBusiness(businessId);
    }

    @PostMapping("/returns")
    public ResponseEntity<PurchaseReturnResponse> createReturn(@Valid @RequestBody PurchaseReturnRequest request) {
        return ResponseEntity.ok(service.createReturn(request));
    }

    @PostMapping("/returns/{id}/approve")
    public ResponseEntity<PurchaseReturnResponse> approve(@PathVariable Long id) {
        return ResponseEntity.ok(service.approveReturn(id));
    }

    @PostMapping("/returns/{id}/reject")
    public ResponseEntity<PurchaseReturnResponse> reject(@PathVariable Long id, @RequestParam(required = false) String reason) {
        return ResponseEntity.ok(service.rejectReturn(id, reason));
    }
}
