package com.biznext.erp.returns;

import java.time.LocalDateTime;
import java.util.List;

public record SalesReturnResponse(
        Long id,
        Long businessId,
        Long salesInvoiceId,
        Long customerId,
        ReturnStatus status,
        String reason,
        Double totalAmount,
        Double refundAmount,
        Long referenceAccountId,
        String createdBy,
        LocalDateTime createdAt,
        LocalDateTime approvedAt,
        LocalDateTime rejectedAt,
        List<SalesReturnItemEntity> items
) {
    public static SalesReturnResponse fromEntity(SalesReturnEntity entity) {
        return new SalesReturnResponse(
                entity.getId(),
                entity.getBusinessId(),
                entity.getSalesInvoiceId(),
                entity.getCustomerId(),
                entity.getStatus(),
                entity.getReason(),
                entity.getTotalAmount(),
                entity.getRefundAmount(),
                entity.getReferenceAccountId(),
                entity.getCreatedBy(),
                entity.getCreatedAt(),
                entity.getApprovedAt(),
                entity.getRejectedAt(),
                entity.getItems()
        );
    }
}
