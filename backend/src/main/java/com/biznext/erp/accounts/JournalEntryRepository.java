package com.biznext.erp.accounts;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface JournalEntryRepository extends JpaRepository<JournalEntryEntity, Long> {
    List<JournalEntryEntity> findByBusinessIdOrderByCreatedAtDesc(Long businessId);
}
