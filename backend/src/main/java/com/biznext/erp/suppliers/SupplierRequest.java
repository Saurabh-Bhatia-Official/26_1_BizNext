package com.biznext.erp.suppliers;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record SupplierRequest(
        @NotNull Long businessId,
        @NotBlank String name,
        String phone,
        @Email String email,
        String address,
        String gstNumber,
        Double balance,
        Boolean active
) {}
