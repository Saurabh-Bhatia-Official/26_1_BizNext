package com.biznext.erp.products;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "products")
public class ProductEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "business_id", nullable = false)
    private Long businessId;

    @Column(name = "product_name", nullable = false)
    private String productName;

    private String sku;

    @Column(name = "category_id")
    private Long categoryId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumns({
            @JoinColumn(name = "category_id", referencedColumnName = "id",
                    insertable = false, updatable = false),
            @JoinColumn(name = "business_id", referencedColumnName = "business_id",
                    insertable = false, updatable = false)
    })
    private ProductCategoryEntity category;

    private String brand;
    private String description;

    @Column(name = "purchase_price", nullable = false)
    private BigDecimal purchasePrice = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal mrp = BigDecimal.ZERO;

    @Column(name = "selling_price", nullable = false)
    private BigDecimal sellingPrice = BigDecimal.ZERO;

    @Column(name = "min_selling_price", nullable = false)
    private BigDecimal minSellingPrice = BigDecimal.ZERO;

    @Column(name = "wholesale_price", nullable = false)
    private BigDecimal wholesalePrice = BigDecimal.ZERO;

    @Column(name = "dealer_price", nullable = false)
    private BigDecimal dealerPrice = BigDecimal.ZERO;

    @Column(name = "tax_percentage", nullable = false)
    private BigDecimal taxPercentage = BigDecimal.ZERO;

    @Column(name = "stock_quantity", nullable = false)
    private BigDecimal stockQuantity = BigDecimal.ZERO;

    @Column(name = "minimum_stock_level", nullable = false)
    private BigDecimal minimumStockLevel = BigDecimal.valueOf(5);

    @Column(nullable = false)
    private String unit = "pcs";

    private String barcode;

    @Column(name = "hsn_sac")
    private String hsnSac;

    @Column(name = "product_image")
    private String productImage;

    @Column(name = "product_image_public_id")
    private String productImagePublicId;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Version
    @Column(nullable = false)
    private Long version = 0L;

    protected ProductEntity() {
    }

    public ProductEntity(Long businessId, ProductRequest request) {
        this.businessId = businessId;
        apply(request);
        this.createdAt = LocalDateTime.now();
        this.updatedAt = this.createdAt;
    }

    public void apply(ProductRequest request) {
        this.productName = request.productName().trim();
        this.sku = emptyToNull(request.sku());
        this.categoryId = request.categoryId();
        this.brand = emptyToNull(request.brand());
        this.description = emptyToNull(request.description());
        this.purchasePrice = valueOrZero(request.purchasePrice());
        this.mrp = valueOrZero(request.mrp());
        this.sellingPrice = valueOrZero(request.sellingPrice());
        this.minSellingPrice = valueOrZero(request.minSellingPrice());
        this.wholesalePrice = valueOrZero(request.wholesalePrice());
        this.dealerPrice = valueOrZero(request.dealerPrice());
        this.taxPercentage = valueOrZero(request.taxPercentage());
        this.stockQuantity = valueOrZero(request.stockQuantity());
        this.minimumStockLevel = request.minimumStockLevel() == null
                ? BigDecimal.valueOf(5) : request.minimumStockLevel();
        this.unit = request.unit() == null || request.unit().isBlank() ? "pcs" : request.unit().trim();
        this.barcode = emptyToNull(request.barcode());
        this.hsnSac = emptyToNull(request.hsnSac());
        this.active = request.active() == null || request.active();
        this.updatedAt = LocalDateTime.now();
    }

    public boolean isLowStock() {
        return stockQuantity.compareTo(minimumStockLevel) <= 0;
    }

    public void setProductImage(String productImage, String publicId) {
        this.productImage = productImage;
        this.productImagePublicId = publicId;
        this.updatedAt = LocalDateTime.now();
    }

    public void setActive(boolean active) {
        this.active = active;
        this.updatedAt = LocalDateTime.now();
    }

    public void setStockQuantity(BigDecimal stockQuantity) {
        this.stockQuantity = stockQuantity;
        this.updatedAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public Long getBusinessId() { return businessId; }
    public String getProductName() { return productName; }
    public String getSku() { return sku; }
    public Long getCategoryId() { return categoryId; }
    public ProductCategoryEntity getCategory() { return category; }
    public String getBrand() { return brand; }
    public String getDescription() { return description; }
    public BigDecimal getPurchasePrice() { return purchasePrice; }
    public BigDecimal getMrp() { return mrp; }
    public BigDecimal getSellingPrice() { return sellingPrice; }
    public BigDecimal getMinSellingPrice() { return minSellingPrice; }
    public BigDecimal getWholesalePrice() { return wholesalePrice; }
    public BigDecimal getDealerPrice() { return dealerPrice; }
    public BigDecimal getTaxPercentage() { return taxPercentage; }
    public BigDecimal getStockQuantity() { return stockQuantity; }
    public BigDecimal getMinimumStockLevel() { return minimumStockLevel; }
    public String getUnit() { return unit; }
    public String getBarcode() { return barcode; }
    public String getHsnSac() { return hsnSac; }
    public String getProductImage() { return productImage; }
    public String getProductImagePublicId() { return productImagePublicId; }
    public boolean isActive() { return active; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }

    private static BigDecimal valueOrZero(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }

    private static String emptyToNull(String value) {
        if (value == null || value.isBlank()) return null;
        return value.trim();
    }
}
