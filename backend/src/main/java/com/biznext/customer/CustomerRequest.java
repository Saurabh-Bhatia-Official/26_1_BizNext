package com.biznext.customer;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Email;

public record CustomerRequest(
        @NotNull(message = "businessId is required") @Positive(message = "businessId must be positive") Long businessId,
        @NotBlank(message = "Customer name is required") String name,
        @NotBlank(message = "Mobile number is required")
        @Pattern(regexp = "^[0-9+\\-() ]{10,15}$", message = "Please enter a valid mobile number")
        String phone,
        @Email(message = "Please enter a valid email address") String email,
        String address,
        String gstNumber,
        Long customerTypeId,
        Double balance,
        Double loyaltyPoints
) {
}
