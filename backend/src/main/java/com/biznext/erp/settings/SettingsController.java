package com.biznext.erp.settings;

import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/settings")
public class SettingsController {
    private final BusinessSettingRepository repository;

    public SettingsController(BusinessSettingRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public Map<String, String> get(@RequestParam Long businessId) {
        Map<String, String> values = new LinkedHashMap<>();
        repository.findByBusinessId(businessId).forEach(item -> values.put(item.getKey(), item.getValue()));
        return values;
    }

    @PutMapping
    @Transactional
    public Map<String, String> update(@RequestParam Long businessId,
                                      @RequestBody Map<String, String> settings) {
        for (Map.Entry<String, String> entry : settings.entrySet()) {
            BusinessSettingEntity.Key key = new BusinessSettingEntity.Key(businessId, entry.getKey());
            BusinessSettingEntity entity = repository.findById(key).orElseGet(BusinessSettingEntity::new);
            entity.setBusinessId(businessId);
            entity.setKey(entry.getKey());
            entity.setValue(entry.getValue());
            repository.save(entity);
        }
        return get(businessId);
    }
}
