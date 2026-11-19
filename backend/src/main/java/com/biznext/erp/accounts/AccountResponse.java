package com.biznext.erp.accounts;

import java.time.LocalDateTime;

public record AccountResponse(
        Long id,
        Long businessId,
        String code,
        String name,
        String type,
        Boolean active,
        LocalDateTime createdAt
) {
    public static AccountResponse fromEntity(AccountEntity entity) {
        return new AccountResponse(
                entity.getId(),
                entity.getBusinessId(),
                entity.getCode(),
                entity.getName(),
                entity.getType(),
                entity.getActive(),
                entity.getCreatedAt()
        );
    }
}
