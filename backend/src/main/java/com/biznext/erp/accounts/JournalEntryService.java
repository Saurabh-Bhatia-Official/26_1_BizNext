package com.biznext.erp.accounts;

import com.biznext.erp.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class JournalEntryService {
    private final JournalEntryRepository journalEntryRepository;
    private final LedgerEntryRepository ledgerEntryRepository;
    private final AccountRepository accountRepository;

    public JournalEntryService(JournalEntryRepository journalEntryRepository,
                              LedgerEntryRepository ledgerEntryRepository,
                              AccountRepository accountRepository) {
        this.journalEntryRepository = journalEntryRepository;
        this.ledgerEntryRepository = ledgerEntryRepository;
        this.accountRepository = accountRepository;
    }

    public List<JournalEntryResponse> getEntries(Long businessId) {
        return journalEntryRepository.findByBusinessIdOrderByCreatedAtDesc(businessId)
                .stream().map(JournalEntryResponse::fromEntity).toList();
    }

    public List<LedgerEntryEntity> getGeneralLedger(Long businessId) {
        return ledgerEntryRepository.findByBusinessIdOrderByCreatedAtDesc(businessId);
    }

    public List<LedgerEntryEntity> getCustomerLedger(Long businessId, Long entityId) {
        return ledgerEntryRepository.findByBusinessIdAndEntityTypeAndEntityIdOrderByCreatedAtDesc(businessId, "customer", entityId);
    }

    public List<LedgerEntryEntity> getSupplierLedger(Long businessId, Long entityId) {
        return ledgerEntryRepository.findByBusinessIdAndEntityTypeAndEntityIdOrderByCreatedAtDesc(businessId, "supplier", entityId);
    }

    @Transactional
    public JournalEntryResponse createJournalEntry(JournalEntryRequest request) {
        if (request.businessId() == null || request.businessId() <= 0) {
            throw new ApiException("A valid business ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.lines() == null || request.lines().isEmpty()) {
            throw new ApiException("At least one journal line is required.", HttpStatus.BAD_REQUEST);
        }

        double totalDebit = request.lines().stream().mapToDouble(l -> l.debit() == null ? 0.0 : l.debit()).sum();
        double totalCredit = request.lines().stream().mapToDouble(l -> l.credit() == null ? 0.0 : l.credit()).sum();
        if (Math.abs(totalDebit - totalCredit) > 0.0001) {
            throw new ApiException("Journal entry must balance: debits must equal credits.", HttpStatus.BAD_REQUEST);
        }

        JournalEntryEntity entry = new JournalEntryEntity();
        entry.setBusinessId(request.businessId());
        entry.setDescription(request.description());
        entry.setReferenceType(request.referenceType());
        entry.setReferenceId(request.referenceId());
        entry.setCreatedBy(request.createdBy());
        entry.setStatus("POSTED");
        entry.setPostedAt(LocalDateTime.now());

        List<JournalEntryLineEntity> lines = new ArrayList<>();
        for (JournalLineRequest line : request.lines()) {
            if (!accountRepository.existsById(line.accountId())) {
                throw new ApiException("Account not found with id " + line.accountId(), HttpStatus.NOT_FOUND);
            }
            JournalEntryLineEntity entityLine = new JournalEntryLineEntity(entry, line.accountId(), line.description(), line.debit(), line.credit());
            lines.add(entityLine);
        }

        entry.setLines(lines);
        for (JournalEntryLineEntity line : lines) {
            line.setJournalEntry(entry);
            LedgerEntryEntity ledgerEntry = new LedgerEntryEntity();
            ledgerEntry.setBusinessId(request.businessId());
            ledgerEntry.setAccountId(line.getAccountId());
            ledgerEntry.setEntryType(line.getDebit() > 0 ? "DEBIT" : "CREDIT");
            ledgerEntry.setAmount(line.getDebit() > 0 ? line.getDebit() : line.getCredit());
            ledgerEntry.setBalance(line.getDebit() > 0 ? line.getDebit() : line.getCredit());
            ledgerEntry.setDescription(line.getDescription());
            ledgerEntry.setReferenceType(request.referenceType());
            ledgerEntry.setReferenceId(request.referenceId());
            ledgerEntryRepository.save(ledgerEntry);
        }

        return JournalEntryResponse.fromEntity(journalEntryRepository.save(entry));
    }

    public List<TrialBalanceRow> getTrialBalance(Long businessId) {
        List<AccountEntity> accounts = accountRepository.findByBusinessIdOrderByCodeAsc(businessId);
        Map<Long, TrialBalanceRow> rows = new LinkedHashMap<>();
        for (AccountEntity account : accounts) {
            rows.put(account.getId(), new TrialBalanceRow(account.getId(), account.getCode(), account.getName(), 0.0, 0.0));
        }

        List<LedgerEntryEntity> entries = ledgerEntryRepository.findByBusinessIdOrderByCreatedAtDesc(businessId);
        for (LedgerEntryEntity entry : entries) {
            TrialBalanceRow existing = rows.get(entry.getAccountId());
            if (existing == null) {
                continue;
            }
            double debit = "DEBIT".equalsIgnoreCase(entry.getEntryType()) ? entry.getAmount() : 0.0;
            double credit = "CREDIT".equalsIgnoreCase(entry.getEntryType()) ? entry.getAmount() : 0.0;
            rows.put(entry.getAccountId(), new TrialBalanceRow(
                    existing.accountId(),
                    existing.accountCode(),
                    existing.accountName(),
                    existing.debit() + debit,
                    existing.credit() + credit
            ));
        }
        return rows.values().stream()
                .sorted(Comparator.comparing(TrialBalanceRow::accountCode))
                .toList();
    }
}
