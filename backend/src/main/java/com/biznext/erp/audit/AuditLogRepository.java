package com.biznext.erp.audit;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;

public interface AuditLogRepository extends JpaRepository<AuditLogEntity, Long> {
    List<AuditLogEntity> findByBusinessIdOrderByCreatedAtDesc(Long businessId);
    List<AuditLogEntity> findByUserNameOrderByCreatedAtDesc(String userName);
    List<AuditLogEntity> findByModuleNameOrderByCreatedAtDesc(String moduleName);
    List<AuditLogEntity> findByActionOrderByCreatedAtDesc(String action);
    List<AuditLogEntity> findByBusinessIdAndCreatedAtBetweenOrderByCreatedAtDesc(Long businessId, LocalDateTime from, LocalDateTime to);
}
