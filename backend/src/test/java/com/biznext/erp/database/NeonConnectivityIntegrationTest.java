package com.biznext.erp.database;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.support.ResourcePropertySource;

import java.io.File;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

public class NeonConnectivityIntegrationTest {

    @Test
    void testNeonDatabaseConnectionAndMigrations() throws Exception {
        StandardEnvironment environment = new StandardEnvironment();
        File envFile = new File(".env");
        if (!envFile.exists()) {
            envFile = new File("backend/.env");
        }
        assertTrue(envFile.exists(), "backend/.env file must exist for integration testing");
        environment.getPropertySources().addFirst(new ResourcePropertySource(new FileSystemResource(envFile)));

        DatabaseConfiguration dbConfig = new DatabaseConfiguration();
        HikariConfig hikariConfig = dbConfig.createConfig(environment);

        try (HikariDataSource dataSource = new HikariDataSource(hikariConfig)) {
            // 1. Verify connection
            try (Connection conn = dataSource.getConnection();
                 Statement stmt = conn.createStatement()) {
                assertNotNull(conn, "Connection should be established");
                assertFalse(conn.isClosed(), "Connection should be open");

                try (ResultSet rs = stmt.executeQuery("SELECT 1 AS alive, current_database() AS db, version() AS ver")) {
                    assertTrue(rs.next(), "SELECT 1 must return a row");
                    assertEquals(1, rs.getInt("alive"));
                    String dbName = rs.getString("db");
                    assertNotNull(dbName);
                    String version = rs.getString("ver");
                    System.out.println("Connected to Neon DB: " + dbName + " | Version: " + version);
                }
            }

            // 2. Run Flyway migration
            Flyway flyway = Flyway.configure()
                    .dataSource(dataSource)
                    .locations("classpath:db/migration")
                    .baselineOnMigrate(true)
                    .load();
            var migrateResult = flyway.migrate();
            System.out.println("Flyway migrations executed: " + migrateResult.migrationsExecuted);

            // 3. Verify tables exist
            try (Connection conn = dataSource.getConnection();
                 Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery(
                         "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")) {
                Set<String> tables = new HashSet<>();
                while (rs.next()) {
                    tables.add(rs.getString("table_name").toLowerCase());
                }
                System.out.println("Existing public tables: " + tables);

                String[] requiredTables = {
                        "businesses", "app_users", "user_businesses",
                        "customers", "customer_types", "sales", "sale_items", "ledger",
                        "products", "product_categories",
                        "suppliers", "purchases", "purchase_items",
                        "inventory_movements", "sales_returns", "purchase_returns",
                        "chart_of_accounts", "journal_entries", "journal_entry_lines",
                        "offers", "loyalty_transactions", "business_settings", "auth_sessions"
                };

                for (String required : requiredTables) {
                    assertTrue(tables.contains(required), "Required table missing: " + required);
                }
            }
        }
    }
}
