package com.biznext.erp.inventory;

import java.time.LocalDateTime;

public record InventoryMovementResponse(
        Long id,
        Long businessId,
        Long productId,
        Long warehouseId,
        InventoryMovementType movementType,
        Double quantity,
        Double unitCost,
        String referenceType,
        Long referenceId,
        String createdBy,
        String note,
        LocalDateTime createdAt
) {
    public static InventoryMovementResponse fromEntity(InventoryMovementEntity entity) {
        return new InventoryMovementResponse(
                entity.getId(),
                entity.getBusinessId(),
                entity.getProductId(),
                entity.getWarehouseId(),
                entity.getMovementType(),
                entity.getQuantity(),
                entity.getUnitCost(),
                entity.getReferenceType(),
                entity.getReferenceId(),
                entity.getCreatedBy(),
                entity.getNote(),
                entity.getCreatedAt()
        );
    }
}
