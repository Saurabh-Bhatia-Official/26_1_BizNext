package com.biznext.erp.returns;

import jakarta.validation.constraints.NotNull;

import java.util.List;

public record PurchaseReturnRequest(
        @NotNull Long businessId,
        @NotNull Long purchaseInvoiceId,
        @NotNull Long supplierId,
        String reason,
        Long referenceAccountId,
        String createdBy,
        @NotNull List<ReturnItemRequest> items
) {}
