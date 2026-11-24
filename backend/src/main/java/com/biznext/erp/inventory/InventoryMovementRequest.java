package com.biznext.erp.inventory;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record InventoryMovementRequest(
        @NotNull Long businessId,
        @NotNull Long productId,
        @NotNull Long warehouseId,
        @NotNull InventoryMovementType movementType,
        @NotNull @Positive Double quantity,
        Double unitCost,
        String referenceType,
        Long referenceId,
        String createdBy,
        String note
) {}
