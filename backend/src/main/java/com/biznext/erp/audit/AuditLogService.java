package com.biznext.erp.audit;

import com.biznext.erp.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class AuditLogService {
    private final AuditLogRepository repository;

    public AuditLogService(AuditLogRepository repository) {
        this.repository = repository;
    }

    public AuditLogResponse recordAudit(AuditLogRequest request) {
        if (request.businessId() == null || request.businessId() <= 0) {
            throw new ApiException("A valid business ID is required.", HttpStatus.BAD_REQUEST);
        }
        AuditLogEntity entity = new AuditLogEntity();
        entity.setBusinessId(request.businessId());
        entity.setUserName(request.userName());
        entity.setModuleName(request.moduleName());
        entity.setEntityType(request.entityType());
        entity.setEntityId(request.entityId());
        entity.setAction(request.action());
        entity.setPreviousValue(request.previousValue());
        entity.setNewValue(request.newValue());
        return AuditLogResponse.fromEntity(repository.save(entity));
    }

    public List<AuditLogResponse> getByBusiness(Long businessId) {
        return repository.findByBusinessIdOrderByCreatedAtDesc(businessId)
                .stream().map(AuditLogResponse::fromEntity).toList();
    }

    public List<AuditLogResponse> getByUser(String userName) {
        return repository.findByUserNameOrderByCreatedAtDesc(userName)
                .stream().map(AuditLogResponse::fromEntity).toList();
    }

    public List<AuditLogResponse> getByModule(String moduleName) {
        return repository.findByModuleNameOrderByCreatedAtDesc(moduleName)
                .stream().map(AuditLogResponse::fromEntity).toList();
    }

    public List<AuditLogResponse> getByDate(Long businessId, LocalDateTime from, LocalDateTime to) {
        return repository.findByBusinessIdAndCreatedAtBetweenOrderByCreatedAtDesc(businessId, from, to)
                .stream().map(AuditLogResponse::fromEntity).toList();
    }
}
