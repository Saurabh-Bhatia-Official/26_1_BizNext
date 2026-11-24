package com.biznext.erp.returns;

import com.biznext.erp.ApiException;
import com.biznext.erp.inventory.InventoryMovementRequest;
import com.biznext.erp.inventory.InventoryMovementService;
import com.biznext.erp.inventory.InventoryMovementType;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class PurchaseReturnService {
    private final PurchaseReturnRepository repository;
    private final InventoryMovementService inventoryMovementService;

    public PurchaseReturnService(PurchaseReturnRepository repository, InventoryMovementService inventoryMovementService) {
        this.repository = repository;
        this.inventoryMovementService = inventoryMovementService;
    }

    public List<PurchaseReturnResponse> getByBusiness(Long businessId) {
        return repository.findByBusinessIdOrderByCreatedAtDesc(businessId)
                .stream().map(PurchaseReturnResponse::fromEntity).toList();
    }

    @Transactional
    public PurchaseReturnResponse createReturn(PurchaseReturnRequest request) {
        validate(request);
        PurchaseReturnEntity entity = new PurchaseReturnEntity();
        entity.setBusinessId(request.businessId());
        entity.setPurchaseInvoiceId(request.purchaseInvoiceId());
        entity.setSupplierId(request.supplierId());
        entity.setReason(request.reason());
        entity.setReferenceAccountId(request.referenceAccountId());
        entity.setCreatedBy(request.createdBy());
        entity.setStatus(ReturnStatus.PENDING);

        List<PurchaseReturnItemEntity> items = new ArrayList<>();
        double total = 0.0;
        for (ReturnItemRequest item : request.items()) {
            if (item.quantity() > (item.originalQuantity() == null ? item.quantity() : item.originalQuantity())) {
                throw new ApiException("Return quantity cannot exceed the original purchase quantity.", HttpStatus.BAD_REQUEST);
            }
            PurchaseReturnItemEntity line = new PurchaseReturnItemEntity(entity, item.productId(), item.quantity(), item.unitPrice(), item.reason());
            total += line.getTotalAmount();
            items.add(line);
        }
        entity.setTotalAmount(total);
        entity.setCreditAmount(total);
        entity.setItems(items);
        for (PurchaseReturnItemEntity item : items) {
            item.setPurchaseReturn(entity);
        }
        return PurchaseReturnResponse.fromEntity(repository.save(entity));
    }

    @Transactional
    public PurchaseReturnResponse approveReturn(Long id) {
        PurchaseReturnEntity entity = repository.findById(id)
                .orElseThrow(() -> new ApiException("Purchase return not found.", HttpStatus.NOT_FOUND));
        entity.setStatus(ReturnStatus.APPROVED);
        entity.setApprovedAt(LocalDateTime.now());
        for (PurchaseReturnItemEntity item : entity.getItems()) {
            inventoryMovementService.createMovement(new InventoryMovementRequest(
                    entity.getBusinessId(),
                    item.getProductId(),
                    1L,
                    InventoryMovementType.RETURN_OUT,
                    item.getQuantity(),
                    item.getUnitPrice(),
                    "PURCHASE_RETURN",
                    entity.getId(),
                    "system",
                    "Approved purchase return"
            ));
        }
        return PurchaseReturnResponse.fromEntity(repository.save(entity));
    }

    @Transactional
    public PurchaseReturnResponse rejectReturn(Long id, String reason) {
        PurchaseReturnEntity entity = repository.findById(id)
                .orElseThrow(() -> new ApiException("Purchase return not found.", HttpStatus.NOT_FOUND));
        entity.setStatus(ReturnStatus.REJECTED);
        entity.setRejectedAt(LocalDateTime.now());
        entity.setReason(reason == null ? entity.getReason() : reason);
        return PurchaseReturnResponse.fromEntity(repository.save(entity));
    }

    private void validate(PurchaseReturnRequest request) {
        if (request.businessId() == null || request.businessId() <= 0) {
            throw new ApiException("A valid business ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.purchaseInvoiceId() == null || request.purchaseInvoiceId() <= 0) {
            throw new ApiException("A valid purchase invoice ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.supplierId() == null || request.supplierId() <= 0) {
            throw new ApiException("A valid supplier ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.items() == null || request.items().isEmpty()) {
            throw new ApiException("At least one return item is required.", HttpStatus.BAD_REQUEST);
        }
    }
}
