package com.biznext.erp.products;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "product_categories", uniqueConstraints =
        @UniqueConstraint(columnNames = {"id", "business_id"}))
public class ProductCategoryEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "business_id", nullable = false)
    private Long businessId;

    @Column(nullable = false)
    private String name;

    private String code;
    private String description;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    protected ProductCategoryEntity() {
    }

    public ProductCategoryEntity(Long businessId, String name) {
        this.businessId = businessId;
        this.name = name;
        this.createdAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public Long getBusinessId() { return businessId; }
    public String getName() { return name; }
    public String getCode() { return code; }
    public String getDescription() { return description; }
    public boolean isActive() { return active; }

    public void rename(String name) {
        this.name = name;
    }
}
