package com.biznext.erp.database;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

@Configuration
public class DatabaseConfiguration {

    @Bean
    public HikariDataSource dataSource(Environment environment) {
        return new HikariDataSource(createConfig(environment));
    }

    HikariConfig createConfig(Environment environment) {
        if (System.getProperty("jdk.net.hosts.file") == null) {
            java.io.File hostsFile = new java.io.File("hosts");
            if (!hostsFile.exists()) {
                hostsFile = new java.io.File("backend/hosts");
            }
            if (hostsFile.exists()) {
                System.setProperty("jdk.net.hosts.file", hostsFile.getAbsolutePath());
            }
        }
        String databaseUrl = firstConfigured(environment, "DATABASE_URL", "NEON_DATABASE_URL");
        String configuredHost = clean(environment.getProperty("PGHOST"));
        if (databaseUrl == null && configuredHost == null) {
            throw new IllegalStateException(
                    "PostgreSQL configuration is missing. Set DATABASE_URL/NEON_DATABASE_URL "
                            + "or PGHOST, PGDATABASE, PGUSER, and PGPASSWORD. "
                            + "For local development, create backend/.env from backend/.env.example.");
        }

        HikariConfig config = new HikariConfig();
        config.setDriverClassName("org.postgresql.Driver");
        int maxPoolSize = environment.getProperty("NEON_POOL_SIZE", Integer.class, 5);
        int minIdle = environment.getProperty("NEON_MIN_IDLE", Integer.class, 0);
        if (maxPoolSize < 1 || minIdle < 0 || minIdle > maxPoolSize) {
            throw new IllegalStateException("NEON_POOL_SIZE must be positive and NEON_MIN_IDLE must be between 0 and the pool size.");
        }
        config.setPoolName("biznext-neon-pool");
        config.setMaximumPoolSize(maxPoolSize);
        config.setMinimumIdle(minIdle);
        config.setConnectionTimeout(30_000);
        config.setValidationTimeout(5_000);

        if (databaseUrl != null) {
            configureFromDatabaseUrl(config, databaseUrl);
            if (config.getUsername() == null) {
                config.setUsername(clean(environment.getProperty("PGUSER")));
            }
            if (config.getPassword() == null) {
                config.setPassword(clean(environment.getProperty("PGPASSWORD")));
            }
        } else {
            configureFromIndividualProperties(config, environment, configuredHost);
        }

        if (config.getUsername() == null || config.getUsername().isBlank()
                || config.getPassword() == null || config.getPassword().isBlank()) {
            throw new IllegalStateException(
                    "PostgreSQL credentials are missing. Provide credentials in the connection URL "
                            + "or set both PGUSER and PGPASSWORD.");
        }
        return config;
    }

    private static void configureFromDatabaseUrl(HikariConfig config, String value) {
        try {
            value = clean(value);
            String jdbcUrl = value.regionMatches(true, 0, "jdbc:", 0, 5)
                    ? value : "jdbc:" + value;
            URI uri = URI.create(jdbcUrl.substring("jdbc:".length()));
            if (!"postgresql".equalsIgnoreCase(uri.getScheme())) {
                throw new IllegalArgumentException("Connection URL must use PostgreSQL.");
            }

            String query = uri.getRawQuery();
            Map<String, String> parameters = query == null ? Map.of()
                    : Arrays.stream(query.split("&"))
                            .map(part -> part.split("=", 2))
                            .collect(Collectors.toMap(
                                    part -> decode(part[0]).toLowerCase(Locale.ROOT),
                                    part -> part.length > 1 ? decode(part[1]) : "",
                                    (first, ignored) -> first));
            String userInfo = uri.getRawUserInfo();
            if (userInfo != null) {
                String[] credentials = userInfo.split(":", 2);
                config.setUsername(decode(credentials[0]));
                if (credentials.length > 1) config.setPassword(decode(credentials[1]));
            }
            if (parameters.containsKey("user")) config.setUsername(parameters.get("user"));
            if (parameters.containsKey("password")) config.setPassword(parameters.get("password"));

            String path = uri.getRawPath() == null ? "" : uri.getRawPath();
            String safeQuery = query == null ? "" : Arrays.stream(query.split("&"))
                    .filter(part -> {
                        String name = decode(part.split("=", 2)[0]);
                        return !"user".equalsIgnoreCase(name) && !"password".equalsIgnoreCase(name);
                    })
                    .collect(Collectors.joining("&"));
            if (!parameters.containsKey("sslmode")) {
                safeQuery = appendQuery(safeQuery, "sslmode=require");
            }
            String authority = uri.getRawAuthority();
            int at = authority.lastIndexOf('@');
            if (at >= 0) authority = authority.substring(at + 1);

            boolean hasChannelBinding = parameters.containsKey("channelbinding") || parameters.containsKey("channel_binding");
            if (authority.contains("-pooler")) {
                safeQuery = safeQuery.replaceAll("(?i)channel_?binding=require", "channelBinding=prefer");
            }
            if (!hasChannelBinding && !safeQuery.toLowerCase(Locale.ROOT).contains("channelbinding")) {
                safeQuery = appendQuery(safeQuery, "channelBinding=prefer");
            }
            config.setJdbcUrl("jdbc:postgresql://" + authority
                    + path + (safeQuery.isEmpty() ? "" : "?" + safeQuery));
        } catch (RuntimeException exception) {
            throw new IllegalStateException(
                    "DATABASE_URL/NEON_DATABASE_URL is not a valid PostgreSQL connection URL.");
        }
    }

    private static void configureFromIndividualProperties(
            HikariConfig config, Environment environment, String host) {
        String database = clean(environment.getProperty("PGDATABASE"));
        String username = clean(environment.getProperty("PGUSER"));
        String password = clean(environment.getProperty("PGPASSWORD"));
        int port = environment.getProperty("PGPORT", Integer.class, 5432);
        if (database == null || username == null || password == null) {
            throw new IllegalStateException(
                    "PGHOST mode requires PGDATABASE, PGUSER, and PGPASSWORD. PGPORT defaults to 5432.");
        }
        if (port < 1 || port > 65535) {
            throw new IllegalStateException("PGPORT must be between 1 and 65535.");
        }
        String sslMode = clean(environment.getProperty("PGSSLMODE"));
        String channelBinding = clean(environment.getProperty("PGCHANNELBINDING"));
        if (sslMode == null) sslMode = "require";
        if (channelBinding == null) channelBinding = "require";

        config.setJdbcUrl("jdbc:postgresql://" + host + ":" + port + "/"
                + database + "?sslmode=" + sslMode + "&channelBinding=" + channelBinding);
        config.setUsername(username);
        config.setPassword(password);
    }

    private static String firstConfigured(Environment environment, String... names) {
        for (String name : names) {
            String value = clean(environment.getProperty(name));
            if (value != null) return value;
        }
        return null;
    }

    private static String clean(String value) {
        if (value == null) return null;
        String cleaned = value.trim();
        if (cleaned.length() >= 2
                && ((cleaned.startsWith("\"") && cleaned.endsWith("\""))
                || (cleaned.startsWith("'") && cleaned.endsWith("'")))) {
            cleaned = cleaned.substring(1, cleaned.length() - 1).trim();
        }
        return cleaned.isBlank() ? null : cleaned;
    }

    private static String decode(String value) {
        return URLDecoder.decode(value, StandardCharsets.UTF_8);
    }

    private static String appendQuery(String query, String parameter) {
        return query.isEmpty() ? parameter : query + "&" + parameter;
    }
}
