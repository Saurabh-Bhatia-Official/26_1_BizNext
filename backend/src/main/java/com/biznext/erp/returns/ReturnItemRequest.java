package com.biznext.erp.returns;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record ReturnItemRequest(
        @NotNull Long productId,
        @NotNull @Positive Double quantity,
        @NotNull @Positive Double unitPrice,
        String reason,
        Double originalQuantity
) {}
