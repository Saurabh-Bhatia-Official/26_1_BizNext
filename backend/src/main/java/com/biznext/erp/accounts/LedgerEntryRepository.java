package com.biznext.erp.accounts;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface LedgerEntryRepository extends JpaRepository<LedgerEntryEntity, Long> {
    List<LedgerEntryEntity> findByBusinessIdOrderByCreatedAtDesc(Long businessId);
    List<LedgerEntryEntity> findByBusinessIdAndAccountIdOrderByCreatedAtDesc(Long businessId, Long accountId);
    List<LedgerEntryEntity> findByBusinessIdAndEntityTypeAndEntityIdOrderByCreatedAtDesc(Long businessId, String entityType, Long entityId);
}
