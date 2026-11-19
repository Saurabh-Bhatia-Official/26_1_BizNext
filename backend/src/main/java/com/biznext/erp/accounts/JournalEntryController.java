package com.biznext.erp.accounts;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/journal")
public class JournalEntryController {
    private final JournalEntryService service;

    public JournalEntryController(JournalEntryService service) {
        this.service = service;
    }

    @GetMapping("/entries")
    public List<JournalEntryResponse> getEntries(@RequestParam Long businessId) {
        return service.getEntries(businessId);
    }

    @GetMapping("/ledger")
    public List<LedgerEntryEntity> getGeneralLedger(@RequestParam Long businessId) {
        return service.getGeneralLedger(businessId);
    }

    @GetMapping("/ledger/customer")
    public List<LedgerEntryEntity> getCustomerLedger(@RequestParam Long businessId, @RequestParam Long entityId) {
        return service.getCustomerLedger(businessId, entityId);
    }

    @GetMapping("/ledger/supplier")
    public List<LedgerEntryEntity> getSupplierLedger(@RequestParam Long businessId, @RequestParam Long entityId) {
        return service.getSupplierLedger(businessId, entityId);
    }

    @GetMapping("/trial-balance")
    public List<TrialBalanceRow> getTrialBalance(@RequestParam Long businessId) {
        return service.getTrialBalance(businessId);
    }

    @PostMapping("/entries")
    public ResponseEntity<JournalEntryResponse> createEntry(@Valid @RequestBody JournalEntryRequest request) {
        return ResponseEntity.ok(service.createJournalEntry(request));
    }
}
