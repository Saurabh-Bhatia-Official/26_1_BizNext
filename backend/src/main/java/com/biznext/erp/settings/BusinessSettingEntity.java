package com.biznext.erp.settings;

import jakarta.persistence.*;

import java.io.Serializable;
import java.time.LocalDateTime;

@Entity
@Table(name = "business_settings")
@IdClass(BusinessSettingEntity.Key.class)
public class BusinessSettingEntity {
    @Id @Column(name = "business_id")
    private Long businessId;
    @Id @Column(name = "key")
    private String key;
    @Column(nullable = false)
    private String value;
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();

    public Long getBusinessId() { return businessId; }
    public void setBusinessId(Long businessId) { this.businessId = businessId; }
    public String getKey() { return key; }
    public void setKey(String key) { this.key = key; }
    public String getValue() { return value; }
    public void setValue(String value) { this.value = value; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }

    public static class Key implements Serializable {
        public Long businessId;
        public String key;
        public Key() {}
        public Key(Long businessId, String key) { this.businessId = businessId; this.key = key; }
        @Override public boolean equals(Object o) { if (!(o instanceof Key k)) return false; return java.util.Objects.equals(businessId,k.businessId) && java.util.Objects.equals(key,k.key); }
        @Override public int hashCode() { return java.util.Objects.hash(businessId, key); }
    }
}
