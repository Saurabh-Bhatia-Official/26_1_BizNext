package com.biznext.erp.products;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record ProductStockAdjustmentRequest(
        @NotNull @Positive Long businessId,
        @NotNull BigDecimal adjustedQuantity,
        @NotBlank @Size(max = 64) String adjustmentType,
        @NotBlank @Size(max = 1000) String reason
) {
}
