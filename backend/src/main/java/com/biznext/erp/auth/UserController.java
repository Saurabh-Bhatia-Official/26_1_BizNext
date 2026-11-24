package com.biznext.erp.auth;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class UserController {
    private final JdbcTemplate jdbc;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public UserController(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @GetMapping("/auth/usernames")
    public Map<String, Object> usernameTaken(@RequestParam String username) {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM app_users WHERE LOWER(username) = LOWER(?)",
                Integer.class, username.trim());
        return Map.of("taken", count != null && count > 0);
    }

    @GetMapping("/users")
    public List<Map<String, Object>> users(@RequestParam(required = false) Long businessId) {
        if (businessId != null) {
            return jdbc.queryForList(
                    "SELECT u.* FROM app_users u JOIN user_businesses ub ON ub.user_id = u.id "
                            + "WHERE ub.business_id = ? AND u.is_active = TRUE ORDER BY u.full_name",
                    businessId);
        }
        return jdbc.queryForList(
                "SELECT * FROM app_users WHERE is_active = TRUE ORDER BY full_name");
    }

    @GetMapping("/users/{id}")
    public Map<String, Object> get(@PathVariable Long id) {
        return jdbc.queryForMap("SELECT * FROM app_users WHERE id = ?", id);
    }

    @PutMapping("/users/{id}")
    public Map<String, Object> update(@PathVariable Long id,
                                      @RequestBody Map<String, Object> request) {
        jdbc.update(
                "UPDATE app_users SET full_name = ?, email = ?, phone = ?, role = ?, is_active = ? WHERE id = ?",
                request.get("fullName"),
                request.get("email"),
                request.get("phone"),
                request.getOrDefault("role", "staff"),
                request.getOrDefault("active", true),
                id);
        return jdbc.queryForMap("SELECT * FROM app_users WHERE id = ?", id);
    }

    @PutMapping("/users/{id}/password")
    @Transactional
    public Map<String, Object> changePassword(@PathVariable Long id,
                                              @RequestBody Map<String, Object> request) {
        String password = String.valueOf(request.get("password"));
        jdbc.update("UPDATE app_users SET password_hash = ? WHERE id = ?",
                passwordEncoder.encode(password), id);
        return Map.of("id", id, "updated", true);
    }
}
