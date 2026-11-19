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
        String databaseUrl = environment.getProperty("DATABASE_URL");
        String configuredHost = environment.getProperty("PGHOST");
        if ((databaseUrl == null || databaseUrl.isBlank())
                && (configuredHost == null || configuredHost.isBlank())) {
            throw new IllegalStateException("Configure DATABASE_URL or PGHOST for PostgreSQL.");
        }

        HikariConfig config = new HikariConfig();
        config.setDriverClassName("org.postgresql.Driver");
        config.setMaximumPoolSize(environment.getProperty("NEON_POOL_SIZE", Integer.class, 5));
        config.setMinimumIdle(environment.getProperty("NEON_MIN_IDLE", Integer.class, 0));
        config.setConnectionTimeout(30_000);
        config.setValidationTimeout(5_000);

        if (databaseUrl != null && !databaseUrl.isBlank()) {
            configureFromDatabaseUrl(config, databaseUrl);
        } else {
            String database = environment.getProperty("PGDATABASE", "neondb");
            String sslMode = environment.getProperty("PGSSLMODE", "require");
            String channelBinding = environment.getProperty("PGCHANNELBINDING", "require");
            config.setJdbcUrl("jdbc:postgresql://" + configuredHost + "/" + database
                    + "?sslmode=" + sslMode + "&channelBinding=" + channelBinding);
        }

        String username = environment.getProperty("PGUSER");
        String password = environment.getProperty("PGPASSWORD");
        if (username != null) config.setUsername(username);
        if (password != null) config.setPassword(password);
        return new HikariDataSource(config);
    }

    private static void configureFromDatabaseUrl(HikariConfig config, String value) {
        try {
            String jdbcUrl = value.startsWith("jdbc:") ? value : "jdbc:" + value;
            URI uri = URI.create(jdbcUrl.substring("jdbc:".length()));
            if (!"postgresql".equalsIgnoreCase(uri.getScheme())) {
                throw new IllegalArgumentException("DATABASE_URL must use PostgreSQL.");
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
            if (!parameters.containsKey("channelbinding")) {
                safeQuery = appendQuery(safeQuery, "channelBinding=require");
            }
            config.setJdbcUrl("jdbc:postgresql://" + uri.getRawAuthority().replaceFirst("^.*@", "")
                    + path + (safeQuery.isEmpty() ? "" : "?" + safeQuery));
        } catch (RuntimeException exception) {
            throw new IllegalStateException("DATABASE_URL is not a valid PostgreSQL connection URL.", exception);
        }
    }

    private static String decode(String value) {
        return URLDecoder.decode(value, StandardCharsets.UTF_8);
    }

    private static String appendQuery(String query, String parameter) {
        return query.isEmpty() ? parameter : query + "&" + parameter;
    }
}
