package com.biznext.erp.loyalty;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/loyalty")
public class LoyaltyController {
    private final JdbcTemplate jdbc;

    public LoyaltyController(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @PostMapping("/adjust")
    @Transactional
    public Map<String, Object> adjust(@RequestBody Map<String, Object> request) {
        Long businessId = ((Number) request.get("businessId")).longValue();
        Long customerId = ((Number) request.get("customerId")).longValue();
        double adjustment = ((Number) request.get("adjustment")).doubleValue();
        String reason = String.valueOf(request.getOrDefault("reason", ""));
        String createdBy = String.valueOf(request.getOrDefault("createdBy", "system"));

        Double current = jdbc.queryForObject(
                "SELECT loyalty_points FROM customers WHERE id = ? AND business_id = ?",
                Double.class, customerId, businessId);
        if (current == null) throw new IllegalArgumentException("Customer not found.");
        double updated = Math.max(0, current + adjustment);
        jdbc.update("UPDATE customers SET loyalty_points = ? WHERE id = ? AND business_id = ?",
                updated, customerId, businessId);
        jdbc.update("INSERT INTO loyalty_transactions (business_id, customer_id, adjustment, reason, created_by) VALUES (?, ?, ?, ?, ?)",
                businessId, customerId, adjustment, reason, createdBy);
        return Map.of("customerId", customerId, "loyaltyPoints", updated);
    }

    @PostMapping("/reset")
    @Transactional
    public Map<String, Object> reset(@RequestBody Map<String, Object> request) {
        Long businessId = ((Number) request.get("businessId")).longValue();
        Long customerId = ((Number) request.get("customerId")).longValue();
        jdbc.update("UPDATE customers SET loyalty_points = 0 WHERE id = ? AND business_id = ?",
                customerId, businessId);
        jdbc.update("INSERT INTO loyalty_transactions (business_id, customer_id, adjustment, reason, created_by) VALUES (?, ?, ?, ?, ?)",
                businessId, customerId, 0.0, "Points reset", "system");
        return Map.of("customerId", customerId, "loyaltyPoints", 0.0);
    }
}
