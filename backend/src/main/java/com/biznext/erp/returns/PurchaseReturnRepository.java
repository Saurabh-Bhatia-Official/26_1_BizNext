package com.biznext.erp.returns;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PurchaseReturnRepository extends JpaRepository<PurchaseReturnEntity, Long> {
    List<PurchaseReturnEntity> findByBusinessIdOrderByCreatedAtDesc(Long businessId);
    List<PurchaseReturnEntity> findBySupplierIdOrderByCreatedAtDesc(Long supplierId);
}
