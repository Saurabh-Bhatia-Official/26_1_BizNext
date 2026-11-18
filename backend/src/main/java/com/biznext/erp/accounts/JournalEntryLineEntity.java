package com.biznext.erp.accounts;

import jakarta.persistence.*;

@Entity
@Table(name = "journal_entry_lines")
public class JournalEntryLineEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "journal_entry_id", nullable = false)
    private JournalEntryEntity journalEntry;

    @Column(name = "account_id", nullable = false)
    private Long accountId;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false)
    private Double debit = 0.0;

    @Column(nullable = false)
    private Double credit = 0.0;

    public JournalEntryLineEntity() {}

    public JournalEntryLineEntity(JournalEntryEntity journalEntry, Long accountId, String description, Double debit, Double credit) {
        this.journalEntry = journalEntry;
        this.accountId = accountId;
        this.description = description;
        this.debit = debit == null ? 0.0 : debit;
        this.credit = credit == null ? 0.0 : credit;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public JournalEntryEntity getJournalEntry() { return journalEntry; }
    public void setJournalEntry(JournalEntryEntity journalEntry) { this.journalEntry = journalEntry; }

    public Long getAccountId() { return accountId; }
    public void setAccountId(Long accountId) { this.accountId = accountId; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Double getDebit() { return debit; }
    public void setDebit(Double debit) { this.debit = debit == null ? 0.0 : debit; }

    public Double getCredit() { return credit; }
    public void setCredit(Double credit) { this.credit = credit == null ? 0.0 : credit; }
}
