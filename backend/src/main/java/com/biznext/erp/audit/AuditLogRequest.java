package com.biznext.erp.audit;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record AuditLogRequest(
        @NotNull Long businessId,
        String userName,
        @NotBlank String moduleName,
        @NotBlank String entityType,
        Long entityId,
        @NotBlank String action,
        String previousValue,
        String newValue
) {}
