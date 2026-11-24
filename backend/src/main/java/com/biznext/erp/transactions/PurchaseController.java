package com.biznext.erp.transactions;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/purchases")
public class PurchaseController {
    private final JdbcTemplate jdbc;

    public PurchaseController(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @GetMapping
    public List<Map<String, Object>> list(@RequestParam Long businessId) {
        return jdbc.queryForList(
                "SELECT p.*, s.name AS supplier_name FROM purchases p "
                        + "LEFT JOIN suppliers s ON s.id = p.supplier_id "
                        + "WHERE p.business_id = ? ORDER BY p.date DESC",
                businessId);
    }

    @GetMapping("/{id}")
    public Map<String, Object> get(@PathVariable Long id,
                                   @RequestParam Long businessId) {
        Map<String, Object> purchase = jdbc.queryForMap(
                "SELECT * FROM purchases WHERE id = ? AND business_id = ?", id, businessId);
        purchase.put("items", jdbc.queryForList(
                "SELECT * FROM purchase_items WHERE purchase_id = ?", id));
        return purchase;
    }

    @PostMapping
    @Transactional
    public Map<String, Object> create(@RequestBody Map<String, Object> request) {
        Long businessId = ((Number) request.get("businessId")).longValue();
        String invoiceNo = String.valueOf(request.get("invoiceNo"));
        Integer duplicate = jdbc.queryForObject(
                "SELECT COUNT(*) FROM purchases WHERE business_id = ? AND invoice_no = ?",
                Integer.class, businessId, invoiceNo);
        if (duplicate != null && duplicate > 0) {
            throw new IllegalArgumentException("Duplicate purchase invoice number.");
        }
        Number id = jdbc.queryForObject(
                "INSERT INTO purchases (business_id, supplier_id, invoice_no, subtotal, discount, "
                        + "tax_amount, grand_total, paid_amount, balance_due, payment_status, status, document_url, document_public_id) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                Number.class, businessId, request.get("supplierId"), invoiceNo,
                request.getOrDefault("subtotal", 0), request.getOrDefault("discount", 0),
                request.getOrDefault("taxAmount", 0), request.getOrDefault("grandTotal", 0),
                request.getOrDefault("paidAmount", 0), request.getOrDefault("balanceDue", 0),
                request.getOrDefault("paymentStatus", "unpaid"), request.getOrDefault("status", "completed"),
                request.get("documentUrl"), request.get("documentPublicId"));

        List<?> items = request.get("items") instanceof List<?> values ? values : List.of();
        for (Object value : items) {
            if (!(value instanceof Map<?, ?> raw)) continue;
            Long productId = number(raw, "productId").longValue();
            double quantity = number(raw, "quantity").doubleValue();
            jdbc.update(
                    "INSERT INTO purchase_items (purchase_id, product_id, quantity, purchase_price, discount, tax_amount, total_amount) "
                            + "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    id.longValue(), productId, quantity,
                    number(raw, "purchasePrice"), number(raw, "discount"),
                    number(raw, "taxAmount"), number(raw, "total"));
            jdbc.update(
                    "UPDATE products SET stock_quantity = stock_quantity + ?, purchase_price = ?, version = version + 1 "
                            + "WHERE id = ? AND business_id = ?",
                    quantity, number(raw, "purchasePrice"), productId, businessId);
            jdbc.update(
                    "INSERT INTO inventory_movements (business_id, product_id, warehouse_id, movement_type, quantity, unit_cost, reference_type, reference_id, created_by, note) "
                            + "VALUES (?, ?, 1, 'STOCK_IN', ?, ?, 'PURCHASE', ?, 'system', ?)",
                    businessId, productId, quantity, number(raw, "purchasePrice"),
                    id.longValue(), invoiceNo);
        }
        return jdbc.queryForMap("SELECT * FROM purchases WHERE id = ?", id.longValue());
    }

    @PutMapping("/{id}/payment")
    @Transactional
    public Map<String, Object> addPayment(@PathVariable Long id,
                                          @RequestParam Long businessId,
                                          @RequestBody Map<String, Object> request) {
        double amount = ((Number) request.get("amount")).doubleValue();
        jdbc.update(
                "UPDATE purchases SET paid_amount = paid_amount + ?, "
                        + "balance_due = GREATEST(0, balance_due - ?) WHERE id = ? AND business_id = ?",
                amount, amount, id, businessId);
        return jdbc.queryForMap("SELECT * FROM purchases WHERE id = ? AND business_id = ?", id, businessId);
    }

    @GetMapping("/last-price")
    public Map<String, Object> lastPrice(@RequestParam Long supplierId,
                                         @RequestParam Long productId,
                                         @RequestParam Long businessId) {
        try {
            Double price = jdbc.queryForObject(
                    "SELECT pi.purchase_price FROM purchases p "
                            + "JOIN purchase_items pi ON pi.purchase_id = p.id "
                            + "WHERE p.business_id = ? AND p.supplier_id = ? AND pi.product_id = ? "
                            + "ORDER BY p.date DESC LIMIT 1",
                    Double.class, businessId, supplierId, productId);
            return Map.of("price", price == null ? 0.0 : price);
        } catch (org.springframework.dao.EmptyResultDataAccessException exception) {
            return Map.of("price", 0.0);
        }
    }

    private static Number number(Map<?, ?> map, String key) {
        Object value = map.get(key);
        return value instanceof Number number ? number : 0;
    }
}
