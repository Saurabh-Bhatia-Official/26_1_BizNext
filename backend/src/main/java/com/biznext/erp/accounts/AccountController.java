package com.biznext.erp.accounts;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/accounts")
public class AccountController {
    private final AccountService service;

    public AccountController(AccountService service) {
        this.service = service;
    }

    @GetMapping
    public List<AccountResponse> getAccounts(@RequestParam Long businessId) {
        return service.getAccounts(businessId);
    }

    @PostMapping
    public ResponseEntity<AccountResponse> createAccount(@Valid @RequestBody AccountRequest request) {
        return ResponseEntity.ok(service.createAccount(request));
    }

    @PutMapping("/{id}")
    public AccountResponse updateAccount(@PathVariable Long id,
                                         @RequestParam Long businessId,
                                         @Valid @RequestBody AccountRequest request) {
        return service.updateAccount(businessId, id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAccount(@PathVariable Long id,
                                              @RequestParam Long businessId) {
        service.deleteAccount(businessId, id);
        return ResponseEntity.noContent().build();
    }
}
