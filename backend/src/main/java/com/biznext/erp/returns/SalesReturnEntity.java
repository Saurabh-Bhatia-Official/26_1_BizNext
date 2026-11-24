package com.biznext.erp.returns;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "sales_returns")
public class SalesReturnEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "business_id", nullable = false)
    private Long businessId;

    @Column(name = "sales_invoice_id", nullable = false)
    private Long salesInvoiceId;

    @Column(name = "customer_id", nullable = false)
    private Long customerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private ReturnStatus status = ReturnStatus.DRAFT;

    @Column(columnDefinition = "TEXT")
    private String reason;

    @Column(name = "total_amount", nullable = false)
    private Double totalAmount = 0.0;

    @Column(name = "refund_amount", nullable = false)
    private Double refundAmount = 0.0;

    @Column(name = "reference_account_id")
    private Long referenceAccountId;

    @Column(name = "created_by")
    private String createdBy;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

    @Column(name = "rejected_at")
    private LocalDateTime rejectedAt;

    @OneToMany(mappedBy = "salesReturn", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<SalesReturnItemEntity> items = new ArrayList<>();

    public SalesReturnEntity() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getBusinessId() { return businessId; }
    public void setBusinessId(Long businessId) { this.businessId = businessId; }

    public Long getSalesInvoiceId() { return salesInvoiceId; }
    public void setSalesInvoiceId(Long salesInvoiceId) { this.salesInvoiceId = salesInvoiceId; }

    public Long getCustomerId() { return customerId; }
    public void setCustomerId(Long customerId) { this.customerId = customerId; }

    public ReturnStatus getStatus() { return status; }
    public void setStatus(ReturnStatus status) { this.status = status; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public Double getTotalAmount() { return totalAmount; }
    public void setTotalAmount(Double totalAmount) { this.totalAmount = totalAmount == null ? 0.0 : totalAmount; }

    public Double getRefundAmount() { return refundAmount; }
    public void setRefundAmount(Double refundAmount) { this.refundAmount = refundAmount == null ? 0.0 : refundAmount; }

    public Long getReferenceAccountId() { return referenceAccountId; }
    public void setReferenceAccountId(Long referenceAccountId) { this.referenceAccountId = referenceAccountId; }

    public String getCreatedBy() { return createdBy; }
    public void setCreatedBy(String createdBy) { this.createdBy = createdBy; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getApprovedAt() { return approvedAt; }
    public void setApprovedAt(LocalDateTime approvedAt) { this.approvedAt = approvedAt; }

    public LocalDateTime getRejectedAt() { return rejectedAt; }
    public void setRejectedAt(LocalDateTime rejectedAt) { this.rejectedAt = rejectedAt; }

    public List<SalesReturnItemEntity> getItems() { return items; }
    public void setItems(List<SalesReturnItemEntity> items) { this.items = items == null ? new ArrayList<>() : items; }
}
