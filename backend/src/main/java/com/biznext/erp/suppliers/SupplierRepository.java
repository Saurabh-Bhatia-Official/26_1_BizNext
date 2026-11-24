package com.biznext.erp.suppliers;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SupplierRepository extends JpaRepository<SupplierEntity, Long> {
    List<SupplierEntity> findByBusinessIdAndActiveOrderByNameAsc(Long businessId, Boolean active);
    List<SupplierEntity> findByBusinessIdOrderByNameAsc(Long businessId);
    Optional<SupplierEntity> findByIdAndBusinessId(Long id, Long businessId);
    boolean existsByBusinessIdAndNameIgnoreCase(Long businessId, String name);
}
