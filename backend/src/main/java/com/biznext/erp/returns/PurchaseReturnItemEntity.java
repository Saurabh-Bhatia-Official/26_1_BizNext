package com.biznext.erp.returns;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "purchase_return_items")
public class PurchaseReturnItemEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "purchase_return_id", nullable = false)
    private PurchaseReturnEntity purchaseReturn;

    @Column(name = "product_id", nullable = false)
    private Long productId;

    @Column(nullable = false)
    private Double quantity = 0.0;

    @Column(name = "unit_price", nullable = false)
    private Double unitPrice = 0.0;

    @Column(name = "total_amount", nullable = false)
    private Double totalAmount = 0.0;

    @Column(columnDefinition = "TEXT")
    private String reason;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public PurchaseReturnItemEntity() {}

    public PurchaseReturnItemEntity(PurchaseReturnEntity purchaseReturn, Long productId, Double quantity,
                                   Double unitPrice, String reason) {
        this.purchaseReturn = purchaseReturn;
        this.productId = productId;
        this.quantity = quantity == null ? 0.0 : quantity;
        this.unitPrice = unitPrice == null ? 0.0 : unitPrice;
        this.totalAmount = this.quantity * this.unitPrice;
        this.reason = reason;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public PurchaseReturnEntity getPurchaseReturn() { return purchaseReturn; }
    public void setPurchaseReturn(PurchaseReturnEntity purchaseReturn) { this.purchaseReturn = purchaseReturn; }

    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }

    public Double getQuantity() { return quantity; }
    public void setQuantity(Double quantity) { this.quantity = quantity == null ? 0.0 : quantity; }

    public Double getUnitPrice() { return unitPrice; }
    public void setUnitPrice(Double unitPrice) { this.unitPrice = unitPrice == null ? 0.0 : unitPrice; }

    public Double getTotalAmount() { return totalAmount; }
    public void setTotalAmount(Double totalAmount) { this.totalAmount = totalAmount == null ? 0.0 : totalAmount; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
