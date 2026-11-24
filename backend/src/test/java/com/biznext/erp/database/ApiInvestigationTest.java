package com.biznext.erp.database;

import com.biznext.BizNextApiApplication;
import com.biznext.erp.inventory.InventoryMovementRepository;
import com.biznext.erp.inventory.InventoryMovementType;
import com.biznext.erp.products.ProductRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;

@SpringBootTest(classes = BizNextApiApplication.class)
public class ApiInvestigationTest {

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
    private ProductRepository productRepository;

    @Autowired
    private InventoryMovementRepository inventoryMovementRepository;

    @Test
    void testFailingProductApis() {
        System.out.println("--- Testing GET All Products (query=null, brand=null, categoryId=null, active=null, lowStockOnly=false) ---");
        try {
            var page = productRepository.findProducts(1L, null, null, null, null, false, PageRequest.of(0, 10));
            System.out.println("GET All Products SUCCESS: " + page.getTotalElements() + " elements");
        } catch (Exception e) {
            System.out.println("GET All Products FAILED with exception: " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
        }

        System.out.println("--- Testing GET Product Search (query='test', brand=null, categoryId=null, active=null, lowStockOnly=false) ---");
        try {
            var page = productRepository.findProducts(1L, "test", null, null, null, false, PageRequest.of(0, 10));
            System.out.println("GET Product Search SUCCESS: " + page.getTotalElements() + " elements");
        } catch (Exception e) {
            System.out.println("GET Product Search FAILED with exception: " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
        }

        System.out.println("--- Testing GET Low Stock Products (query=null, brand=null, categoryId=null, active=null, lowStockOnly=true) ---");
        try {
            var page = productRepository.findProducts(1L, null, null, null, null, true, PageRequest.of(0, 10));
            System.out.println("GET Low Stock Products SUCCESS: " + page.getTotalElements() + " elements");
        } catch (Exception e) {
            System.out.println("GET Low Stock Products FAILED with exception: " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
        }
    }

    @Test
    void testFailingInventoryApis() {
        System.out.println("--- Testing GET All Movements (productId=null, warehouseId=null, type=null, search=null) ---");
        try {
            var list = inventoryMovementRepository.searchMovements(1L, null, null, null, null);
            System.out.println("GET All Movements SUCCESS: " + list.size() + " movements");
        } catch (Exception e) {
            System.out.println("GET All Movements FAILED with exception: " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
        }

        System.out.println("--- Testing GET Available Stock (productId=1, warehouseId=1, type=null, search=null) ---");
        try {
            var list = inventoryMovementRepository.searchMovements(1L, 1L, 1L, null, null);
            System.out.println("GET Available Stock SUCCESS: " + list.size() + " movements");
        } catch (Exception e) {
            System.out.println("GET Available Stock FAILED with exception: " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
        }

        System.out.println("--- Testing GET Search with search='test' ---");
        try {
            var list = inventoryMovementRepository.searchMovements(1L, null, null, null, "test");
            System.out.println("GET Search SUCCESS: " + list.size() + " movements");
        } catch (Exception e) {
            System.out.println("GET Search FAILED with exception: " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
        }
    }
}
