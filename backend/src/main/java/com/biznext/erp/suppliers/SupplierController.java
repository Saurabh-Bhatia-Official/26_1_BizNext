package com.biznext.erp.suppliers;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/suppliers")
public class SupplierController {
    private final SupplierService service;

    public SupplierController(SupplierService service) {
        this.service = service;
    }

    @GetMapping
    public List<SupplierResponse> getSuppliers(
            @RequestParam Long businessId,
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return service.getSuppliers(businessId, includeInactive).stream()
                .map(SupplierResponse::from).toList();
    }

    @GetMapping("/{id}")
    public SupplierResponse getSupplier(@PathVariable Long id, @RequestParam Long businessId) {
        return SupplierResponse.from(service.getSupplier(businessId, id));
    }

    @PostMapping
    public ResponseEntity<SupplierResponse> create(@Valid @RequestBody SupplierRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(SupplierResponse.from(service.create(request)));
    }

    @PutMapping("/{id}")
    public SupplierResponse update(@PathVariable Long id, @RequestParam Long businessId,
                                   @Valid @RequestBody SupplierRequest request) {
        return SupplierResponse.from(service.update(businessId, id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id, @RequestParam Long businessId) {
        service.delete(businessId, id);
        return ResponseEntity.noContent().build();
    }
}
