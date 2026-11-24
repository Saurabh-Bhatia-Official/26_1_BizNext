package com.biznext.erp.suppliers;

import java.time.LocalDateTime;

public record SupplierResponse(
        Long id,
        Long businessId,
        String name,
        String phone,
        String email,
        String address,
        String gstNumber,
        Double balance,
        Boolean active,
        LocalDateTime createdAt
) {
    public static SupplierResponse from(SupplierEntity entity) {
        return new SupplierResponse(
                entity.getId(), entity.getBusinessId(), entity.getName(), entity.getPhone(),
                entity.getEmail(), entity.getAddress(), entity.getGstNumber(),
                entity.getBalance() == null ? 0.0 : entity.getBalance().doubleValue(),
                entity.getActive(), entity.getCreatedAt());
    }
}
