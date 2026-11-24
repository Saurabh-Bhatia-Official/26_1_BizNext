package com.biznext.erp.accounts;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record JournalEntryRequest(
        @NotNull Long businessId,
        @NotBlank String description,
        String referenceType,
        Long referenceId,
        String createdBy,
        @NotNull List<JournalLineRequest> lines
) {}
