package com.biznext.erp.settings;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BusinessSettingRepository
        extends JpaRepository<BusinessSettingEntity, BusinessSettingEntity.Key> {
    List<BusinessSettingEntity> findByBusinessId(Long businessId);
}
