package com.biznext.erp.products;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record ProductCategoryRequest(
        @NotNull @Positive Long businessId,
        @NotBlank @Size(max = 255) String name
) {
}
