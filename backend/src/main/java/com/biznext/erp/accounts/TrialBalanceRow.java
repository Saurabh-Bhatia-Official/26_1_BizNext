package com.biznext.erp.accounts;

public record TrialBalanceRow(Long accountId, String accountCode, String accountName, Double debit, Double credit) {}
