package com.biznext.erp.accounts;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

public record JournalLineRequest(
        @NotNull Long accountId,
        @NotNull @PositiveOrZero Double debit,
        @NotNull @PositiveOrZero Double credit,
        String description
) {}
