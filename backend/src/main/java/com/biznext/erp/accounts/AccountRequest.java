package com.biznext.erp.accounts;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record AccountRequest(
        @NotNull Long businessId,
        @NotBlank String code,
        @NotBlank String name,
        @NotBlank String type
) {}
