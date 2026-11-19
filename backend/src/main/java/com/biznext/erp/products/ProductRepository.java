package com.biznext.erp.products;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface ProductRepository extends JpaRepository<ProductEntity, Long> {
    @EntityGraph(attributePaths = "category")
    Optional<ProductEntity> findByIdAndBusinessId(Long id, Long businessId);

    boolean existsByBusinessIdAndSkuIgnoreCase(Long businessId, String sku);
    boolean existsByBusinessIdAndCategoryId(Long businessId, Long categoryId);

    @EntityGraph(attributePaths = "category")
    @Query("""
            SELECT p FROM ProductEntity p
            WHERE p.businessId = :businessId
              AND (:query IS NULL OR
                   LOWER(p.productName) LIKE LOWER(CONCAT('%', :query, '%')) OR
                   LOWER(COALESCE(p.sku, '')) LIKE LOWER(CONCAT('%', :query, '%')) OR
                   LOWER(COALESCE(p.barcode, '')) LIKE LOWER(CONCAT('%', :query, '%')))
              AND (:categoryId IS NULL OR p.categoryId = :categoryId)
              AND (:brand IS NULL OR LOWER(COALESCE(p.brand, '')) = LOWER(:brand))
              AND (:active IS NULL OR p.active = :active)
              AND (:lowStockOnly = FALSE OR p.stockQuantity <= p.minimumStockLevel)
            """)
    Page<ProductEntity> findProducts(
            @Param("businessId") Long businessId,
            @Param("query") String query,
            @Param("categoryId") Long categoryId,
            @Param("brand") String brand,
            @Param("active") Boolean active,
            @Param("lowStockOnly") boolean lowStockOnly,
            Pageable pageable);
}
