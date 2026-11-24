package com.biznext.erp.inventory;

import jakarta.validation.Valid;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/inventory")
public class InventoryMovementController {
    private final InventoryMovementService service;

    public InventoryMovementController(InventoryMovementService service) {
        this.service = service;
    }

    @GetMapping("/movements")
    public List<InventoryMovementResponse> getMovements(
            @RequestParam Long businessId,
            @RequestParam(required = false) Long productId,
            @RequestParam(required = false) Long warehouseId,
            @RequestParam(required = false) InventoryMovementType type,
            @RequestParam(required = false) String search
    ) {
        return service.getMovements(businessId, productId, warehouseId, type, search);
    }

    @GetMapping("/movements/page")
    public List<InventoryMovementResponse> getMovementsPage(
            @RequestParam Long businessId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        return service.getMovementsPage(businessId, pageable).getContent();
    }

    @GetMapping("/movements/product/{productId}")
    public List<InventoryMovementResponse> getProductHistory(@PathVariable Long productId,
                                                           @RequestParam Long businessId) {
        return service.getProductMovementHistory(businessId, productId);
    }

    @GetMapping("/movements/warehouse/{warehouseId}")
    public List<InventoryMovementResponse> getWarehouseHistory(@PathVariable Long warehouseId,
                                                             @RequestParam Long businessId) {
        return service.getWarehouseMovementHistory(businessId, warehouseId);
    }

    @GetMapping("/stock")
    public Double getAvailableStock(@RequestParam Long businessId,
                                   @RequestParam Long productId,
                                   @RequestParam Long warehouseId) {
        return service.getAvailableStock(businessId, productId, warehouseId);
    }

    @PostMapping("/movements")
    public ResponseEntity<InventoryMovementResponse> createMovement(@Valid @RequestBody InventoryMovementRequest request) {
        return ResponseEntity.ok(service.createMovement(request));
    }
}
