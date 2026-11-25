package com.biznext.erp.discounts;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class DiscountController {
    private final JdbcTemplate jdbc;

    public DiscountController(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @GetMapping("/customer-discounts")
    public Map<String, Object> getCustomer(@RequestParam Long businessId,
                                           @RequestParam Long customerId) {
        try {
            return jdbc.queryForMap(
                    "SELECT * FROM customer_discounts WHERE business_id = ? AND customer_id = ?",
                    businessId, customerId);
        } catch (org.springframework.dao.EmptyResultDataAccessException exception) {
            return Map.of();
        }
    }

    @PutMapping("/customer-discounts")
    @Transactional
    public Map<String, Object> upsertCustomer(@RequestBody Map<String, Object> request) {
        Long businessId = ((Number) request.get("businessId")).longValue();
        Long customerId = ((Number) request.get("customerId")).longValue();
        jdbc.update(
                "INSERT INTO customer_discounts (business_id, customer_id, discount_percentage, discount_amount, is_active) "
                        + "VALUES (?, ?, ?, ?, ?) "
                        + "ON CONFLICT (business_id, customer_id) DO UPDATE SET "
                        + "discount_percentage = EXCLUDED.discount_percentage, "
                        + "discount_amount = EXCLUDED.discount_amount, is_active = EXCLUDED.is_active",
                businessId, customerId,
                request.getOrDefault("discountPercentage", 0),
                request.getOrDefault("discountAmount", 0),
                request.getOrDefault("active", true));
        return jdbc.queryForMap(
                "SELECT * FROM customer_discounts WHERE business_id = ? AND customer_id = ?",
                businessId, customerId);
    }

    @DeleteMapping("/customer-discounts/{id}")
    public void deleteCustomer(@PathVariable Long id) {
        jdbc.update("DELETE FROM customer_discounts WHERE id = ?", id);
    }

    @GetMapping("/product-discounts")
    public Map<String, Object> getProduct(@RequestParam Long businessId,
                                          @RequestParam Long productId) {
        try {
            return jdbc.queryForMap(
                    "SELECT * FROM product_discounts WHERE business_id = ? AND product_id = ?",
                    businessId, productId);
        } catch (org.springframework.dao.EmptyResultDataAccessException exception) {
            return Map.of();
        }
    }

    @PutMapping("/product-discounts")
    @Transactional
    public Map<String, Object> upsertProduct(@RequestBody Map<String, Object> request) {
        Long businessId = ((Number) request.get("businessId")).longValue();
        Long productId = ((Number) request.get("productId")).longValue();
        jdbc.update(
                "INSERT INTO product_discounts (business_id, product_id, discount_percentage, discount_amount, is_active) "
                        + "VALUES (?, ?, ?, ?, ?) "
                        + "ON CONFLICT (business_id, product_id) DO UPDATE SET "
                        + "discount_percentage = EXCLUDED.discount_percentage, "
                        + "discount_amount = EXCLUDED.discount_amount, is_active = EXCLUDED.is_active",
                businessId, productId,
                request.getOrDefault("discountPercentage", 0),
                request.getOrDefault("discountAmount", 0),
                request.getOrDefault("active", true));
        return jdbc.queryForMap(
                "SELECT * FROM product_discounts WHERE business_id = ? AND product_id = ?",
                businessId, productId);
    }

    @DeleteMapping("/product-discounts/{id}")
    public void deleteProduct(@PathVariable Long id) {
        jdbc.update("DELETE FROM product_discounts WHERE id = ?", id);
    }
}
