package com.biznext.erp.auth;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final JdbcTemplate jdbc;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public AuthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @PostMapping("/register")
    @Transactional
    public Map<String, Object> register(@RequestBody Map<String, Object> request) {
        String username = String.valueOf(request.get("username")).trim().toLowerCase();
        String password = String.valueOf(request.get("password"));
        String fullName = String.valueOf(request.get("fullName"));
        String email = request.get("email") == null ? null : String.valueOf(request.get("email"));
        String phone = request.get("phone") == null ? null : String.valueOf(request.get("phone"));
        String role = String.valueOf(request.getOrDefault("role", "owner"));

        Integer existing = jdbc.queryForObject(
                "SELECT COUNT(*) FROM app_users WHERE username = ?", Integer.class, username);
        if (existing != null && existing > 0) {
            throw new IllegalArgumentException("Username already exists.");
        }
        Number key = jdbc.queryForObject(
                "INSERT INTO app_users (username, password_hash, full_name, email, phone, role) "
                        + "VALUES (?, ?, ?, ?, ?, ?) RETURNING id",
                Number.class, username, passwordEncoder.encode(password), fullName, email, phone, role);
        if (request.get("businessId") != null) {
            Long businessId = ((Number) request.get("businessId")).longValue();
            jdbc.update(
                    "INSERT INTO user_businesses (user_id, business_id, role) VALUES (?, ?, ?) "
                            + "ON CONFLICT (user_id, business_id) DO UPDATE SET role = EXCLUDED.role",
                    key.longValue(), businessId, role);
        }
        return Map.of("id", key.longValue(), "username", username, "fullName", fullName, "role", role);
    }

    @PostMapping("/login")
    @Transactional
    public Map<String, Object> login(@RequestBody Map<String, Object> request) {
        String username = String.valueOf(request.get("username")).trim().toLowerCase();
        String password = String.valueOf(request.get("password"));
        Map<String, Object> user = jdbc.queryForMap(
                "SELECT id, password_hash, full_name, role, is_active FROM app_users WHERE username = ?",
                username);
        if (!(Boolean.TRUE.equals(user.get("is_active")))
                || !passwordEncoder.matches(password, String.valueOf(user.get("password_hash")))) {
            throw new IllegalArgumentException("Invalid username or password.");
        }

        Long userId = ((Number) user.get("id")).longValue();
        Long businessId = request.get("businessId") == null
                ? null : ((Number) request.get("businessId")).longValue();
        String token = UUID.randomUUID() + "-" + UUID.randomUUID();
        jdbc.update(
                "INSERT INTO auth_sessions (user_id, business_id, token_hash, expires_at) VALUES (?, ?, ?, ?)",
                userId, businessId, sha256(token), LocalDateTime.now().plusDays(30));
        return Map.of(
                "token", token,
                "userId", userId,
                "businessId", businessId == null ? 0 : businessId,
                "username", username,
                "fullName", String.valueOf(user.get("full_name")),
                "role", String.valueOf(user.get("role")));
    }

    @PostMapping("/purge-sample")
    @Transactional
    public Map<String, Object> purgeSample(@RequestParam(defaultValue = "1") Long businessId) {
        jdbc.update("DELETE FROM loyalty_transactions WHERE business_id = ?", businessId);
        jdbc.update("DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE business_id = ?)", businessId);
        jdbc.update("DELETE FROM sales WHERE business_id = ?", businessId);
        jdbc.update("DELETE FROM purchase_items WHERE purchase_id IN (SELECT id FROM purchases WHERE business_id = ?)", businessId);
        jdbc.update("DELETE FROM purchases WHERE business_id = ?", businessId);
        jdbc.update("DELETE FROM inventory_movements WHERE business_id = ?", businessId);
        return Map.of("businessId", businessId, "purged", true);
    }

    private static String sha256(String value) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256")
                            .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 is unavailable.", exception);
        }
    }
}
