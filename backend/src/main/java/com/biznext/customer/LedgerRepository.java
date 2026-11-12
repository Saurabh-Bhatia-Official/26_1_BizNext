package com.biznext.customer;

import org.springframework.data.jpa.repository.JpaRepository;

public interface LedgerRepository extends JpaRepository<LedgerEntity, Long> {
    boolean existsByEntityTypeAndEntityId(String entityType, Long entityId);
    boolean existsByBusinessIdAndEntityTypeAndEntityId(Long businessId, String entityType, Long entityId);
}
