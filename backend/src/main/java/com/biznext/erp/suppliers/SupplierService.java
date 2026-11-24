package com.biznext.erp.suppliers;

import com.biznext.erp.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class SupplierService {
    private final SupplierRepository repository;

    public SupplierService(SupplierRepository repository) {
        this.repository = repository;
    }

    public List<SupplierEntity> getSuppliers(Long businessId, boolean includeInactive) {
        if (businessId == null || businessId <= 0) {
            throw new ApiException("A valid business ID is required.", HttpStatus.BAD_REQUEST);
        }
        return includeInactive
                ? repository.findByBusinessIdOrderByNameAsc(businessId)
                : repository.findByBusinessIdAndActiveOrderByNameAsc(businessId, true);
    }

    public SupplierEntity getSupplier(Long businessId, Long id) {
        return repository.findByIdAndBusinessId(id, businessId)
                .orElseThrow(() -> new ApiException("Supplier not found.", HttpStatus.NOT_FOUND));
    }

    @Transactional
    public SupplierEntity create(SupplierRequest request) {
        validate(request);
        if (repository.existsByBusinessIdAndNameIgnoreCase(request.businessId(), request.name().trim())) {
            throw new ApiException("A supplier with this name already exists.", HttpStatus.CONFLICT);
        }
        SupplierEntity entity = new SupplierEntity();
        apply(entity, request);
        return repository.save(entity);
    }

    @Transactional
    public SupplierEntity update(Long businessId, Long id, SupplierRequest request) {
        validate(request);
        if (!businessId.equals(request.businessId())) {
            throw new ApiException("Business ID mismatch.", HttpStatus.BAD_REQUEST);
        }
        SupplierEntity entity = getSupplier(businessId, id);
        apply(entity, request);
        return repository.save(entity);
    }

    @Transactional
    public void delete(Long businessId, Long id) {
        SupplierEntity entity = getSupplier(businessId, id);
        entity.setActive(false);
        repository.save(entity);
    }

    private void validate(SupplierRequest request) {
        if (request.businessId() == null || request.businessId() <= 0) {
            throw new ApiException("A valid business ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.name() == null || request.name().trim().isEmpty()) {
            throw new ApiException("Supplier name is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.balance() != null && request.balance() < 0) {
            throw new ApiException("Supplier balance cannot be negative.", HttpStatus.BAD_REQUEST);
        }
    }

    private void apply(SupplierEntity entity, SupplierRequest request) {
        entity.setBusinessId(request.businessId());
        entity.setName(request.name().trim());
        entity.setPhone(request.phone());
        entity.setEmail(request.email());
        entity.setAddress(request.address());
        entity.setGstNumber(request.gstNumber());
        entity.setBalance(request.balance() == null ? BigDecimal.ZERO : BigDecimal.valueOf(request.balance()));
        entity.setActive(request.active() == null || request.active());
    }
}
