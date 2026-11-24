package com.biznext.erp;

import com.biznext.erp.accounts.AccountRepository;
import com.biznext.erp.accounts.JournalEntryRequest;
import com.biznext.erp.accounts.JournalEntryRepository;
import com.biznext.erp.accounts.JournalEntryService;
import com.biznext.erp.accounts.JournalLineRequest;
import com.biznext.erp.accounts.LedgerEntryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@ExtendWith(MockitoExtension.class)
class JournalEntryServiceTest {
    @Mock
    private JournalEntryRepository journalEntryRepository;

    @Mock
    private LedgerEntryRepository ledgerEntryRepository;

    @Mock
    private AccountRepository accountRepository;

    @InjectMocks
    private JournalEntryService service;

    @Test
    void shouldRejectUnbalancedJournalEntry() {
        JournalEntryRequest request = new JournalEntryRequest(
                1L,
                "Test entry",
                "SALES",
                77L,
                "admin",
                List.of(
                        new JournalLineRequest(1L, 100.0, 0.0, "Cash"),
                        new JournalLineRequest(2L, 0.0, 50.0, "Sales")
                )
        );

        ApiException exception = assertThrows(ApiException.class, () -> service.createJournalEntry(request));
        assertEquals("Journal entry must balance: debits must equal credits.", exception.getMessage());
    }
}
