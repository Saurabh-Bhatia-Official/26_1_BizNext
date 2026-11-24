package com.biznext.erp.products;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;

public record ProductRequest(
        @NotNull @Positive Long businessId,
        @NotBlank @Size(max = 255) String productName,
        @Size(max = 128) String sku,
        Long categoryId,
        @Size(max = 255) String brand,
        String description,
        @NotNull @DecimalMin("0.0") BigDecimal purchasePrice,
        @DecimalMin("0.0") BigDecimal mrp,
        @NotNull @DecimalMin("0.0") BigDecimal sellingPrice,
        @DecimalMin("0.0") BigDecimal minSellingPrice,
        @DecimalMin("0.0") BigDecimal wholesalePrice,
        @DecimalMin("0.0") BigDecimal dealerPrice,
        @DecimalMin("0.0") @DecimalMax("100.0") BigDecimal taxPercentage,
        @DecimalMin("0.0") BigDecimal stockQuantity,
        @DecimalMin("0.0") BigDecimal minimumStockLevel,
        @Size(max = 32) String unit,
        @Size(max = 128) String barcode,
        @Size(max = 64) String hsnSac,
        Boolean active
) {
}
