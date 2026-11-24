package com.biznext.erp.accounts;

import java.time.LocalDateTime;
import java.util.List;

public record JournalEntryResponse(
        Long id,
        Long businessId,
        String description,
        String referenceType,
        Long referenceId,
        String status,
        String createdBy,
        LocalDateTime createdAt,
        LocalDateTime postedAt,
        List<JournalEntryLineEntity> lines
) {
    public static JournalEntryResponse fromEntity(JournalEntryEntity entity) {
        return new JournalEntryResponse(
                entity.getId(),
                entity.getBusinessId(),
                entity.getDescription(),
                entity.getReferenceType(),
                entity.getReferenceId(),
                entity.getStatus(),
                entity.getCreatedBy(),
                entity.getCreatedAt(),
                entity.getPostedAt(),
                entity.getLines()
        );
    }
}
