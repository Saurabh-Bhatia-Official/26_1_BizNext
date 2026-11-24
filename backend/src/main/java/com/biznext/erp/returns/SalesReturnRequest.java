package com.biznext.erp.returns;

import jakarta.validation.constraints.NotNull;

import java.util.List;

public record SalesReturnRequest(
        @NotNull Long businessId,
        @NotNull Long salesInvoiceId,
        @NotNull Long customerId,
        String reason,
        Long referenceAccountId,
        String createdBy,
        @NotNull List<ReturnItemRequest> items
) {}
