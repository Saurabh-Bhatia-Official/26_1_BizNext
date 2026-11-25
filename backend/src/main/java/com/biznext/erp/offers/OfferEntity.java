package com.biznext.erp.offers;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "offers")
public class OfferEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "business_id", nullable = false)
    private Long businessId;
    @Column(nullable = false)
    private String name;
    @Column(name = "offer_type", nullable = false)
    private String offerType;
    @Column(name = "discount_type", nullable = false)
    private String discountType;
    @Column(name = "discount_value", nullable = false)
    private BigDecimal discountValue = BigDecimal.ZERO;
    @Column(name = "min_qty", nullable = false)
    private BigDecimal minQty = BigDecimal.ZERO;
    @Column(name = "min_amount", nullable = false)
    private BigDecimal minAmount = BigDecimal.ZERO;
    @Column(name = "apply_to", nullable = false)
    private String applyTo = "all";
    @Column(name = "target_id")
    private Long targetId;
    @Column(name = "buy_qty", nullable = false)
    private BigDecimal buyQty = BigDecimal.ZERO;
    @Column(name = "get_qty", nullable = false)
    private BigDecimal getQty = BigDecimal.ZERO;
    @Column(name = "start_date")
    private LocalDateTime startDate;
    @Column(name = "end_date")
    private LocalDateTime endDate;
    @Column(name = "is_active", nullable = false)
    private Boolean active = true;
    @Column(name = "poster_url")
    private String posterUrl;
    @Column(name = "poster_public_id")
    private String posterPublicId;
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getBusinessId() { return businessId; }
    public void setBusinessId(Long businessId) { this.businessId = businessId; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getOfferType() { return offerType; }
    public void setOfferType(String offerType) { this.offerType = offerType; }
    public String getDiscountType() { return discountType; }
    public void setDiscountType(String discountType) { this.discountType = discountType; }
    public BigDecimal getDiscountValue() { return discountValue; }
    public void setDiscountValue(BigDecimal discountValue) { this.discountValue = discountValue == null ? BigDecimal.ZERO : discountValue; }
    public BigDecimal getMinQty() { return minQty; }
    public void setMinQty(BigDecimal minQty) { this.minQty = minQty == null ? BigDecimal.ZERO : minQty; }
    public BigDecimal getMinAmount() { return minAmount; }
    public void setMinAmount(BigDecimal minAmount) { this.minAmount = minAmount == null ? BigDecimal.ZERO : minAmount; }
    public String getApplyTo() { return applyTo; }
    public void setApplyTo(String applyTo) { this.applyTo = applyTo; }
    public Long getTargetId() { return targetId; }
    public void setTargetId(Long targetId) { this.targetId = targetId; }
    public BigDecimal getBuyQty() { return buyQty; }
    public void setBuyQty(BigDecimal buyQty) { this.buyQty = buyQty == null ? BigDecimal.ZERO : buyQty; }
    public BigDecimal getGetQty() { return getQty; }
    public void setGetQty(BigDecimal getQty) { this.getQty = getQty == null ? BigDecimal.ZERO : getQty; }
    public LocalDateTime getStartDate() { return startDate; }
    public void setStartDate(LocalDateTime startDate) { this.startDate = startDate; }
    public LocalDateTime getEndDate() { return endDate; }
    public void setEndDate(LocalDateTime endDate) { this.endDate = endDate; }
    public Boolean getActive() { return active; }
    public void setActive(Boolean active) { this.active = active; }
    public String getPosterUrl() { return posterUrl; }
    public void setPosterUrl(String posterUrl) { this.posterUrl = posterUrl; }
    public String getPosterPublicId() { return posterPublicId; }
    public void setPosterPublicId(String posterPublicId) { this.posterPublicId = posterPublicId; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
