package com.biznext.erp.products;

import jakarta.validation.constraints.NotBlank;

public record ProductStatusRequest(@NotBlank String status) {
}
