package com.biznext.erp.returns;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SalesReturnRepository extends JpaRepository<SalesReturnEntity, Long> {
    List<SalesReturnEntity> findByBusinessIdOrderByCreatedAtDesc(Long businessId);
    List<SalesReturnEntity> findByCustomerIdOrderByCreatedAtDesc(Long customerId);
}
