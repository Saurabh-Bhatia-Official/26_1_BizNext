package com.biznext.customer;

public record CustomerResponse(
        Long id,
        Long businessId,
        String name,
        String phone,
        String email,
        String address,
        String gstNumber,
        Long customerTypeId,
        Double balance,
        Double loyaltyPoints,
        String createdAt
) {
    public static CustomerResponse fromEntity(CustomerEntity entity) {
        return new CustomerResponse(
                entity.getId(),
                entity.getBusinessId(),
                entity.getName(),
                entity.getPhone(),
                entity.getEmail(),
                entity.getAddress(),
                entity.getGstNumber(),
                entity.getCustomerTypeId(),
                entity.getBalance(),
                entity.getLoyaltyPoints(),
                entity.getCreatedAt() == null ? null : entity.getCreatedAt().toString()
        );
    }
}
