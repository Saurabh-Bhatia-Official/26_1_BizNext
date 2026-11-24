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
public class SalesReturnService {
    private final SalesReturnRepository repository;
    private final InventoryMovementService inventoryMovementService;

    public SalesReturnService(SalesReturnRepository repository, InventoryMovementService inventoryMovementService) {
        this.repository = repository;
        this.inventoryMovementService = inventoryMovementService;
    }

    public List<SalesReturnResponse> getByBusiness(Long businessId) {
        return repository.findByBusinessIdOrderByCreatedAtDesc(businessId)
                .stream().map(SalesReturnResponse::fromEntity).toList();
    }

    @Transactional
    public SalesReturnResponse createReturn(SalesReturnRequest request) {
        validate(request);
        SalesReturnEntity entity = new SalesReturnEntity();
        entity.setBusinessId(request.businessId());
        entity.setSalesInvoiceId(request.salesInvoiceId());
        entity.setCustomerId(request.customerId());
        entity.setReason(request.reason());
        entity.setReferenceAccountId(request.referenceAccountId());
        entity.setCreatedBy(request.createdBy());
        entity.setStatus(ReturnStatus.PENDING);

        List<SalesReturnItemEntity> items = new ArrayList<>();
        double total = 0.0;
        for (ReturnItemRequest item : request.items()) {
            if (item.quantity() > (item.originalQuantity() == null ? item.quantity() : item.originalQuantity())) {
                throw new ApiException("Return quantity cannot exceed the original invoice quantity.", HttpStatus.BAD_REQUEST);
            }
            SalesReturnItemEntity line = new SalesReturnItemEntity(entity, item.productId(), item.quantity(), item.unitPrice(), item.reason());
            total += line.getTotalAmount();
            items.add(line);
        }
        entity.setTotalAmount(total);
        entity.setRefundAmount(total);
        entity.setItems(items);
        for (SalesReturnItemEntity item : items) {
            item.setSalesReturn(entity);
        }
        return SalesReturnResponse.fromEntity(repository.save(entity));
    }

    @Transactional
    public SalesReturnResponse approveReturn(Long id) {
        SalesReturnEntity entity = repository.findById(id)
                .orElseThrow(() -> new ApiException("Sales return not found.", HttpStatus.NOT_FOUND));
        entity.setStatus(ReturnStatus.APPROVED);
        entity.setApprovedAt(LocalDateTime.now());
        for (SalesReturnItemEntity item : entity.getItems()) {
            inventoryMovementService.createMovement(new InventoryMovementRequest(
                    entity.getBusinessId(),
                    item.getProductId(),
                    1L,
                    InventoryMovementType.RETURN_IN,
                    item.getQuantity(),
                    item.getUnitPrice(),
                    "SALES_RETURN",
                    entity.getId(),
                    "system",
                    "Approved sales return"
            ));
        }
        return SalesReturnResponse.fromEntity(repository.save(entity));
    }

    @Transactional
    public SalesReturnResponse rejectReturn(Long id, String reason) {
        SalesReturnEntity entity = repository.findById(id)
                .orElseThrow(() -> new ApiException("Sales return not found.", HttpStatus.NOT_FOUND));
        entity.setStatus(ReturnStatus.REJECTED);
        entity.setRejectedAt(LocalDateTime.now());
        entity.setReason(reason == null ? entity.getReason() : reason);
        return SalesReturnResponse.fromEntity(repository.save(entity));
    }

    private void validate(SalesReturnRequest request) {
        if (request.businessId() == null || request.businessId() <= 0) {
            throw new ApiException("A valid business ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.salesInvoiceId() == null || request.salesInvoiceId() <= 0) {
            throw new ApiException("A valid sales invoice ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.customerId() == null || request.customerId() <= 0) {
            throw new ApiException("A valid customer ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (request.items() == null || request.items().isEmpty()) {
            throw new ApiException("At least one return item is required.", HttpStatus.BAD_REQUEST);
        }
    }
}
