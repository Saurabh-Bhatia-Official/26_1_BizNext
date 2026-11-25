package com.biznext.erp.accounts;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AccountRepository extends JpaRepository<AccountEntity, Long> {
    List<AccountEntity> findByBusinessIdOrderByCodeAsc(Long businessId);
    boolean existsByBusinessIdAndCode(Long businessId, String code);
}
