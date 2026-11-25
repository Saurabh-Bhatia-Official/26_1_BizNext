package com.biznext.erp.database;

import com.zaxxer.hikari.HikariConfig;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.junit.jupiter.api.Assertions.*;

class DatabaseConfigurationTest {
    private final DatabaseConfiguration configuration = new DatabaseConfiguration();

    @Test
    void buildsSecureJdbcUrlFromIndividualNeonVariables() {
        MockEnvironment environment = new MockEnvironment()
                .withProperty("PGHOST", "ep-example-pooler.neon.tech")
                .withProperty("PGPORT", "5433")
                .withProperty("PGDATABASE", "neondb")
                .withProperty("PGUSER", "test-user")
                .withProperty("PGPASSWORD", "test-password");

        HikariConfig config = configuration.createConfig(environment);

        assertEquals(
                "jdbc:postgresql://ep-example-pooler.neon.tech:5433/neondb?sslmode=require&channelBinding=require",
                config.getJdbcUrl());
        assertEquals("test-user", config.getUsername());
        assertEquals("test-password", config.getPassword());
        assertEquals("biznext-neon-pool", config.getPoolName());
    }

    @Test
    void parsesPostgresUrlAndDefaultsSslWithoutLeavingCredentialsInJdbcUrl() {
        MockEnvironment environment = new MockEnvironment()
                .withProperty("NEON_DATABASE_URL",
                        "postgresql://test-user:test%40password@ep-example.neon.tech/neondb");

        HikariConfig config = configuration.createConfig(environment);

        assertEquals("test-user", config.getUsername());
        assertEquals("test@password", config.getPassword());
        assertTrue(config.getJdbcUrl().contains("sslmode=require"));
        assertTrue(config.getJdbcUrl().contains("channelBinding=prefer"));
        assertFalse(config.getJdbcUrl().contains("test-user"));
        assertFalse(config.getJdbcUrl().contains("test%40password"));
    }

    @Test
    void reportsMissingIndividualConnectionSettingsClearly() {
        MockEnvironment environment = new MockEnvironment()
                .withProperty("PGHOST", "ep-example.neon.tech");

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> configuration.createConfig(environment));

        assertTrue(exception.getMessage().contains("PGDATABASE, PGUSER, and PGPASSWORD"));
    }
}
