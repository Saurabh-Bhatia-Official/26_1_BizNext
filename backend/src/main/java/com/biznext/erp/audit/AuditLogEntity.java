package com.biznext.erp.audit;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "audit_logs")
public class AuditLogEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "business_id", nullable = false)
    private Long businessId;

    @Column(name = "user_name")
    private String userName;

    @Column(name = "module_name", nullable = false)
    private String moduleName;

    @Column(name = "entity_type", nullable = false)
    private String entityType;

    @Column(name = "entity_id")
    private Long entityId;

    @Column(nullable = false)
    private String action;

    @Column(name = "previous_value", columnDefinition = "TEXT")
    private String previousValue;

    @Column(name = "new_value", columnDefinition = "TEXT")
    private String newValue;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public AuditLogEntity() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getBusinessId() { return businessId; }
    public void setBusinessId(Long businessId) { this.businessId = businessId; }

    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }

    public String getModuleName() { return moduleName; }
    public void setModuleName(String moduleName) { this.moduleName = moduleName; }

    public String getEntityType() { return entityType; }
    public void setEntityType(String entityType) { this.entityType = entityType; }

    public Long getEntityId() { return entityId; }
    public void setEntityId(Long entityId) { this.entityId = entityId; }

    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }

    public String getPreviousValue() { return previousValue; }
    public void setPreviousValue(String previousValue) { this.previousValue = previousValue; }

    public String getNewValue() { return newValue; }
    public void setNewValue(String newValue) { this.newValue = newValue; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
