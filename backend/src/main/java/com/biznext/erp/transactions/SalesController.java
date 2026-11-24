package com.biznext.erp.transactions;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/sales")
public class SalesController {
    private final JdbcTemplate jdbc;

    public SalesController(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @GetMapping
    public List<Map<String, Object>> list(@RequestParam Long businessId) {
        return jdbc.queryForList(
                "SELECT * FROM sales WHERE business_id = ? ORDER BY date DESC",
                businessId);
    }

    @GetMapping("/{id}")
    public Map<String, Object> get(@PathVariable Long id,
                                   @RequestParam Long businessId) {
        Map<String, Object> sale = jdbc.queryForMap(
                "SELECT * FROM sales WHERE id = ? AND business_id = ?", id, businessId);
        sale.put("items", jdbc.queryForList(
                "SELECT * FROM sale_items WHERE sale_id = ?", id));
        return sale;
    }

    @PostMapping
    @Transactional
    public Map<String, Object> create(@RequestBody Map<String, Object> request) {
        Long businessId = ((Number) request.get("businessId")).longValue();
        String invoiceNo = String.valueOf(request.get("invoiceNo"));
        Integer duplicate = jdbc.queryForObject(
                "SELECT COUNT(*) FROM sales WHERE business_id = ? AND invoice_no = ?",
                Integer.class, businessId, invoiceNo);
        if (duplicate != null && duplicate > 0) {
            throw new IllegalArgumentException("Duplicate invoice number.");
        }
        Number id = jdbc.queryForObject(
                "INSERT INTO sales (business_id, invoice_no, customer_id, subtotal, discount, "
                        + "gst_amount, grand_total, paid_amount, balance_due, payment_mode, account_id, notes, status, "
                        + "points_earned, points_redeemed, loyalty_discount) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                Number.class, businessId, invoiceNo,
                request.get("customerId"), request.getOrDefault("subtotal", 0),
                request.getOrDefault("discount", 0), request.getOrDefault("gstAmount", 0),
                request.getOrDefault("grandTotal", 0), request.getOrDefault("paidAmount", 0),
                request.getOrDefault("balanceDue", 0), request.getOrDefault("paymentMode", "Cash"),
                request.get("accountId"), request.get("notes"), request.getOrDefault("status", "completed"),
                request.getOrDefault("pointsEarned", 0), request.getOrDefault("pointsRedeemed", 0),
                request.getOrDefault("loyaltyDiscount", 0));

        List<?> items = request.get("items") instanceof List<?> values ? values : List.of();
        for (Object value : items) {
            if (!(value instanceof Map<?, ?> raw)) continue;
            Long productId = number(raw, "productId").longValue();
            double quantity = number(raw, "quantity").doubleValue();
            Double stock = jdbc.queryForObject(
                    "SELECT stock_quantity FROM products WHERE id = ? AND business_id = ?",
                    Double.class, productId, businessId);
            if (stock == null || stock < quantity) {
                throw new IllegalArgumentException("Insufficient stock for product " + productId);
            }
            jdbc.update(
                    "INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, purchase_price, discount, tax_amount, total_amount) "
                            + "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    id.longValue(), productId, quantity,
                    number(raw, "price"), number(raw, "purchasePrice"),
                    number(raw, "discount"), number(raw, "gstAmount"),
                    number(raw, "total"));
            jdbc.update(
                    "UPDATE products SET stock_quantity = stock_quantity - ?, version = version + 1 "
                            + "WHERE id = ? AND business_id = ?",
                    quantity, productId, businessId);
            jdbc.update(
                    "INSERT INTO inventory_movements (business_id, product_id, warehouse_id, movement_type, quantity, unit_cost, reference_type, reference_id, created_by, note) "
                            + "VALUES (?, ?, 1, 'STOCK_OUT', ?, ?, 'SALE', ?, 'system', ?)",
                    businessId, productId, quantity, number(raw, "purchasePrice"),
                    id.longValue(), invoiceNo);
        }
        return jdbc.queryForMap("SELECT * FROM sales WHERE id = ?", id.longValue());
    }

    @GetMapping("/next-invoice")
    public Map<String, Object> nextInvoice(@RequestParam Long businessId) {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM sales WHERE business_id = ?", Integer.class, businessId);
        return Map.of("invoiceNo", "INV-" + String.format("%06d", (count == null ? 0 : count) + 1));
    }

    @PutMapping("/{id}/payment")
    @Transactional
    public Map<String, Object> addPayment(@PathVariable Long id,
                                          @RequestBody Map<String, Object> request) {
        double amount = ((Number) request.get("amount")).doubleValue();
        jdbc.update(
                "UPDATE sales SET paid_amount = paid_amount + ?, balance_due = GREATEST(0, balance_due - ?) "
                        + "WHERE id = ?",
                amount, amount, id);
        return jdbc.queryForMap("SELECT * FROM sales WHERE id = ?", id);
    }

    @DeleteMapping("/{id}")
    @Transactional
    public Map<String, Object> voidSale(@PathVariable Long id,
                                       @RequestParam Long businessId) {
        List<Map<String, Object>> items = jdbc.queryForList(
                "SELECT product_id, quantity FROM sale_items WHERE sale_id = ?", id);
        for (Map<String, Object> item : items) {
            Number productId = (Number) item.get("product_id");
            Number quantity = (Number) item.get("quantity");
            jdbc.update(
                    "UPDATE products SET stock_quantity = stock_quantity + ?, version = version + 1 "
                            + "WHERE id = ? AND business_id = ?",
                    quantity.doubleValue(), productId.longValue(), businessId);
        }
        jdbc.update("UPDATE sales SET status = 'voided' WHERE id = ? AND business_id = ?",
                id, businessId);
        return Map.of("id", id, "status", "voided");
    }

    private static Number number(Map<?, ?> map, String key) {
        Object value = map.get(key);
        return value instanceof Number number ? number : 0;
    }
}
