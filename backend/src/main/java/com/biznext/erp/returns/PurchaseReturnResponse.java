package com.biznext.erp.returns;

import java.time.LocalDateTime;
import java.util.List;

public record PurchaseReturnResponse(
        Long id,
        Long businessId,
        Long purchaseInvoiceId,
        Long supplierId,
        ReturnStatus status,
        String reason,
        Double totalAmount,
        Double creditAmount,
        Long referenceAccountId,
        String createdBy,
        LocalDateTime createdAt,
        LocalDateTime approvedAt,
        LocalDateTime rejectedAt,
        List<PurchaseReturnItemEntity> items
) {
    public static PurchaseReturnResponse fromEntity(PurchaseReturnEntity entity) {
        return new PurchaseReturnResponse(
                entity.getId(),
                entity.getBusinessId(),
                entity.getPurchaseInvoiceId(),
                entity.getSupplierId(),
                entity.getStatus(),
                entity.getReason(),
                entity.getTotalAmount(),
                entity.getCreditAmount(),
                entity.getReferenceAccountId(),
                entity.getCreatedBy(),
                entity.getCreatedAt(),
                entity.getApprovedAt(),
                entity.getRejectedAt(),
                entity.getItems()
        );
    }
}
