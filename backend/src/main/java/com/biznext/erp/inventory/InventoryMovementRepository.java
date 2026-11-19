package com.biznext.erp.inventory;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface InventoryMovementRepository extends JpaRepository<InventoryMovementEntity, Long> {
    Page<InventoryMovementEntity> findByBusinessIdOrderByCreatedAtDesc(Long businessId, Pageable pageable);

    @Query("SELECT m FROM InventoryMovementEntity m WHERE m.businessId = :businessId " +
            "AND (:productId IS NULL OR m.productId = :productId) " +
            "AND (:warehouseId IS NULL OR m.warehouseId = :warehouseId) " +
            "AND (:type IS NULL OR m.movementType = :type) " +
            "AND (:search IS NULL OR LOWER(COALESCE(m.note, '')) LIKE LOWER(CONCAT('%', :search, '%'))) " +
            "ORDER BY m.createdAt DESC")
    List<InventoryMovementEntity> searchMovements(@Param("businessId") Long businessId,
                                                 @Param("productId") Long productId,
                                                 @Param("warehouseId") Long warehouseId,
                                                 @Param("type") InventoryMovementType type,
                                                 @Param("search") String search);

    List<InventoryMovementEntity> findByBusinessIdAndProductIdOrderByCreatedAtDesc(Long businessId, Long productId);
    List<InventoryMovementEntity> findByBusinessIdAndWarehouseIdOrderByCreatedAtDesc(Long businessId, Long warehouseId);
}
