package com.biznext.erp.business;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/businesses")
public class BusinessController {
    private final JdbcTemplate jdbc;

    public BusinessController(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @GetMapping
    public List<Map<String, Object>> list(@RequestParam(required = false) Long userId) {
        if (userId != null) {
            return jdbc.queryForList(
                    "SELECT b.*, ub.role AS user_role FROM businesses b "
                            + "JOIN user_businesses ub ON ub.business_id = b.id "
                            + "WHERE ub.user_id = ? AND b.is_active = TRUE ORDER BY b.name",
                    userId);
        }
        return jdbc.queryForList("SELECT * FROM businesses WHERE is_active = TRUE ORDER BY name");
    }

    @GetMapping("/{id}")
    public Map<String, Object> get(@PathVariable Long id) {
        return jdbc.queryForMap("SELECT * FROM businesses WHERE id = ?", id);
    }

    @PostMapping
    @Transactional
    public Map<String, Object> create(@RequestBody Map<String, Object> request) {
        Number id = jdbc.queryForObject(
                "INSERT INTO businesses (name, type, address, phone, email, gst_number, currency, currency_symbol, owner_id) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                Number.class,
                request.get("name"),
                request.getOrDefault("type", "Retail Shop"),
                request.get("address"),
                request.get("phone"),
                request.get("email"),
                request.get("gstNumber"),
                request.getOrDefault("currency", "INR"),
                request.getOrDefault("currencySymbol", "₹"),
                request.get("ownerId"));
        return jdbc.queryForMap("SELECT * FROM businesses WHERE id = ?", id.longValue());
    }

    @PutMapping("/{id}")
    public Map<String, Object> update(@PathVariable Long id,
                                      @RequestBody Map<String, Object> request) {
        jdbc.update(
                "UPDATE businesses SET name = ?, type = ?, address = ?, phone = ?, email = ?, "
                        + "gst_number = ?, currency = ?, currency_symbol = ? WHERE id = ?",
                request.get("name"),
                request.getOrDefault("type", "Retail Shop"),
                request.get("address"),
                request.get("phone"),
                request.get("email"),
                request.get("gstNumber"),
                request.getOrDefault("currency", "INR"),
                request.getOrDefault("currencySymbol", "₹"),
                id);
        return jdbc.queryForMap("SELECT * FROM businesses WHERE id = ?", id);
    }

    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@PathVariable Long id) {
        jdbc.update("UPDATE businesses SET is_active = FALSE WHERE id = ?", id);
        return Map.of("id", id, "deleted", true);
    }
}
