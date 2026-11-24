package com.biznext.erp.database;

import com.biznext.BizNextApiApplication;
import com.biznext.erp.offers.OfferRepository;
import com.biznext.erp.suppliers.SupplierRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest(classes = BizNextApiApplication.class)
public class HibernateContextIntegrationTest {

    static {
        java.io.File hosts = new java.io.File("hosts");
        if (!hosts.exists()) {
            hosts = new java.io.File("backend/hosts");
        }
        if (hosts.exists()) {
            System.setProperty("jdk.net.hosts.file", hosts.getAbsolutePath());
        }
    }

    @Autowired
    private EntityManager entityManager;

    @Autowired
    private OfferRepository offerRepository;

    @Autowired
    private SupplierRepository supplierRepository;

    @Test
    void contextLoadsAndSchemaValidationPasses() {
        assertNotNull(entityManager, "EntityManager should be injected successfully");
        assertNotNull(offerRepository, "OfferRepository should be injected successfully");
        assertNotNull(supplierRepository, "SupplierRepository should be injected successfully");

        // Verify that querying offers table succeeds without schema errors
        var offers = offerRepository.findByBusinessIdOrderByCreatedAtDesc(1L);
        assertNotNull(offers);

        // Verify that querying suppliers table succeeds without schema errors
        var suppliers = supplierRepository.findByBusinessIdOrderByNameAsc(1L);
        assertNotNull(suppliers);

        System.out.println("HibernateContextIntegrationTest: PASSED - Context loaded, EntityManagerFactory validated all entities against Neon DB successfully.");
    }
}
