package com.biznext.erp.database;

import com.biznext.BizNextApiApplication;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.List;

@SpringBootTest(classes = BizNextApiApplication.class)
public class QueryFixExperimentTest {

    static {
        java.io.File hosts = new java.io.File("hosts");
        if (!hosts.exists()) {
            hosts = new java.io.File("backend/hosts");
        }
        if (hosts.exists()) {
            System.setProperty("jdk.net.hosts.file", hosts.getAbsolutePath());
        }
        System.setProperty("java.net.preferIPv4Stack", "true");
    }

    @Autowired
    private EntityManager em;

    @Test
    void testVariantsForInventoryMovements() {
        // Variant 1: CAST(:search AS string)
        System.out.println("--- Testing Variant 1: CAST(:search AS string) ---");
        try {
            String jpql = "SELECT m FROM InventoryMovementEntity m WHERE m.businessId = :businessId " +
                    "AND (:productId IS NULL OR m.productId = :productId) " +
                    "AND (:warehouseId IS NULL OR m.warehouseId = :warehouseId) " +
                    "AND (:type IS NULL OR m.movementType = :type) " +
                    "AND (CAST(:search AS string) IS NULL OR LOWER(COALESCE(m.note, '')) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))) " +
                    "ORDER BY m.createdAt DESC";
            List<?> res = em.createQuery(jpql)
                    .setParameter("businessId", 1L)
                    .setParameter("productId", null)
                    .setParameter("warehouseId", null)
                    .setParameter("type", null)
                    .setParameter("search", null)
                    .getResultList();
            System.out.println("Variant 1 SUCCESS! Result size: " + res.size());
        } catch (Exception e) {
            System.out.println("Variant 1 FAILED: " + e.getMessage());
            e.printStackTrace();
        }

        // Variant 2: Reversing order (COALESCE/LIKE first, IS NULL second)
        System.out.println("--- Testing Variant 2: Condition order reversed without cast ---");
        try {
            String jpql = "SELECT m FROM InventoryMovementEntity m WHERE m.businessId = :businessId " +
                    "AND (:productId IS NULL OR m.productId = :productId) " +
                    "AND (:warehouseId IS NULL OR m.warehouseId = :warehouseId) " +
                    "AND (:type IS NULL OR m.movementType = :type) " +
                    "AND (LOWER(COALESCE(m.note, '')) LIKE LOWER(CONCAT('%', :search, '%')) OR :search IS NULL) " +
                    "ORDER BY m.createdAt DESC";
            List<?> res = em.createQuery(jpql)
                    .setParameter("businessId", 1L)
                    .setParameter("productId", null)
                    .setParameter("warehouseId", null)
                    .setParameter("type", null)
                    .setParameter("search", null)
                    .getResultList();
            System.out.println("Variant 2 SUCCESS! Result size: " + res.size());
        } catch (Exception e) {
            System.out.println("Variant 2 FAILED: " + e.getMessage());
        }

        // Variant 3: CAST in LOWER and IS NULL
        System.out.println("--- Testing Variant 3: (:search IS NULL OR LOWER(COALESCE(m.note, '')) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))) ---");
        try {
            String jpql = "SELECT m FROM InventoryMovementEntity m WHERE m.businessId = :businessId " +
                    "AND (:productId IS NULL OR m.productId = :productId) " +
                    "AND (:warehouseId IS NULL OR m.warehouseId = :warehouseId) " +
                    "AND (:type IS NULL OR m.movementType = :type) " +
                    "AND (:search IS NULL OR LOWER(COALESCE(m.note, '')) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))) " +
                    "ORDER BY m.createdAt DESC";
            List<?> res = em.createQuery(jpql)
                    .setParameter("businessId", 1L)
                    .setParameter("productId", null)
                    .setParameter("warehouseId", null)
                    .setParameter("type", null)
                    .setParameter("search", null)
                    .getResultList();
            System.out.println("Variant 3 SUCCESS! Result size: " + res.size());
        } catch (Exception e) {
            System.out.println("Variant 3 FAILED: " + e.getMessage());
        }
    }

    @Test
    void testVariantsForProducts() {
        // Variant 1: CAST query and brand as string
        System.out.println("--- Testing Product Variant 1: CAST(:query AS string) and CAST(:brand AS string) ---");
        try {
            String jpql = """
                    SELECT p FROM ProductEntity p
                    WHERE p.businessId = :businessId
                      AND (CAST(:query AS string) IS NULL OR
                           LOWER(p.productName) LIKE LOWER(CONCAT('%', CAST(:query AS string), '%')) OR
                           LOWER(COALESCE(p.sku, '')) LIKE LOWER(CONCAT('%', CAST(:query AS string), '%')) OR
                           LOWER(COALESCE(p.barcode, '')) LIKE LOWER(CONCAT('%', CAST(:query AS string), '%')))
                      AND (:categoryId IS NULL OR p.categoryId = :categoryId)
                      AND (CAST(:brand AS string) IS NULL OR LOWER(COALESCE(p.brand, '')) = LOWER(CAST(:brand AS string)))
                      AND (:active IS NULL OR p.active = :active)
                      AND (:lowStockOnly = FALSE OR p.stockQuantity <= p.minimumStockLevel)
                    """;
            List<?> res = em.createQuery(jpql)
                    .setParameter("businessId", 1L)
                    .setParameter("query", null)
                    .setParameter("categoryId", null)
                    .setParameter("brand", null)
                    .setParameter("active", null)
                    .setParameter("lowStockOnly", false)
                    .getResultList();
            System.out.println("Product Variant 1 (nulls) SUCCESS! Result size: " + res.size());

            // Also test with query='test' and brand=null
            res = em.createQuery(jpql)
                    .setParameter("businessId", 1L)
                    .setParameter("query", "test")
                    .setParameter("categoryId", null)
                    .setParameter("brand", null)
                    .setParameter("active", null)
                    .setParameter("lowStockOnly", false)
                    .getResultList();
            System.out.println("Product Variant 1 (query='test') SUCCESS! Result size: " + res.size());

            // Also test with query=null and lowStockOnly=true
            res = em.createQuery(jpql)
                    .setParameter("businessId", 1L)
                    .setParameter("query", null)
                    .setParameter("categoryId", null)
                    .setParameter("brand", null)
                    .setParameter("active", null)
                    .setParameter("lowStockOnly", true)
                    .getResultList();
            System.out.println("Product Variant 1 (lowStockOnly=true) SUCCESS! Result size: " + res.size());
        } catch (Exception e) {
            System.out.println("Product Variant 1 FAILED: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
