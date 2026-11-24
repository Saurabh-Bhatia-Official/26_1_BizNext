package com.biznext.erp.audit;

import java.time.LocalDateTime;

public record AuditLogResponse(
        Long id,
        Long businessId,
        String userName,
        String moduleName,
        String entityType,
        Long entityId,
        String action,
        String previousValue,
        String newValue,
        LocalDateTime createdAt
) {
    public static AuditLogResponse fromEntity(AuditLogEntity entity) {
        return new AuditLogResponse(
                entity.getId(),
                entity.getBusinessId(),
                entity.getUserName(),
                entity.getModuleName(),
                entity.getEntityType(),
                entity.getEntityId(),
                entity.getAction(),
                entity.getPreviousValue(),
                entity.getNewValue(),
                entity.getCreatedAt()
        );
    }
}
