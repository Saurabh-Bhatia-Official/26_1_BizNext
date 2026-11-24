package com.biznext.erp.products;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ProductCategoryRepository extends JpaRepository<ProductCategoryEntity, Long> {
    List<ProductCategoryEntity> findAllByBusinessIdAndActiveTrueOrderByNameAsc(Long businessId);
    Optional<ProductCategoryEntity> findByIdAndBusinessId(Long id, Long businessId);
    boolean existsByBusinessIdAndNameIgnoreCase(Long businessId, String name);
}
