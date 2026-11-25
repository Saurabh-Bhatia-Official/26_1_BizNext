package com.biznext.erp.inventory;

import com.biznext.erp.ApiException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class InventoryMovementService {
    private final InventoryMovementRepository repository;

    public InventoryMovementService(InventoryMovementRepository repository) {
        this.repository = repository;
    }

    public InventoryMovementResponse createMovement(InventoryMovementRequest request) {
        validateRequest(request);
        InventoryMovementEntity entity = new InventoryMovementEntity(
                request.businessId(),
                request.productId(),
                request.warehouseId(),
                request.movementType(),
                request.quantity(),
                request.unitCost(),
                request.referenceType(),
                request.referenceId(),
                request.createdBy(),
                request.note());
        return InventoryMovementResponse.fromEntity(repository.save(entity));
    }

    public List<InventoryMovementResponse> getMovements(Long businessId, Long productId,
                                                       Long warehouseId, InventoryMovementType type,
                                                       String search) {
        return repository.searchMovements(businessId, productId, warehouseId, type, search)
                .stream().map(InventoryMovementResponse::fromEntity).toList();
    }

    public Page<InventoryMovementResponse> getMovementsPage(Long businessId, Pageable pageable) {
        return repository.findByBusinessIdOrderByCreatedAtDesc(businessId, pageable)
                .map(InventoryMovementResponse::fromEntity);
    }

    public List<InventoryMovementResponse> getProductMovementHistory(Long businessId, Long productId) {
        return repository.findByBusinessIdAndProductIdOrderByCreatedAtDesc(businessId, productId)
                .stream().map(InventoryMovementResponse::fromEntity).toList();
    }

    public List<InventoryMovementResponse> getWarehouseMovementHistory(Long businessId, Long warehouseId) {
        return repository.findByBusinessIdAndWarehouseIdOrderByCreatedAtDesc(businessId, warehouseId)
                .stream().map(InventoryMovementResponse::fromEntity).toList();
    }

    public Double getAvailableStock(Long businessId, Long productId, Long warehouseId) {
        return repository.searchMovements(businessId, productId, warehouseId, null, null)
                .stream()
                .mapToDouble(m -> switch (m.getMovementType()) {
                    case STOCK_IN, RETURN_IN, ADJUSTMENT -> m.getQuantity();
                    case STOCK_OUT, RETURN_OUT, TRANSFER -> -m.getQuantity();
                })
                .sum();
    }

    private void validateRequest(InventoryMovementRequest request) {
        if (request.businessId() == null || request.businessId() <= 0) {
            throw new ApiException("A valid business ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.productId() == null || request.productId() <= 0) {
            throw new ApiException("A valid product ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.warehouseId() == null || request.warehouseId() <= 0) {
            throw new ApiException("A valid warehouse ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.movementType() == null) {
            throw new ApiException("Movement type is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.quantity() == null || request.quantity() <= 0) {
            throw new ApiException("Quantity must be greater than zero.", HttpStatus.BAD_REQUEST);
        }
        if (request.movementType() == InventoryMovementType.STOCK_OUT
                || request.movementType() == InventoryMovementType.RETURN_OUT
                || request.movementType() == InventoryMovementType.TRANSFER) {
            double available = getAvailableStock(request.businessId(), request.productId(), request.warehouseId());
            if (available < request.quantity()) {
                throw new ApiException("Insufficient stock available for this movement.", HttpStatus.CONFLICT);
            }
        }
    }
}
