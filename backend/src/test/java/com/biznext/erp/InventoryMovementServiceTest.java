package com.biznext.erp;

import com.biznext.erp.inventory.InventoryMovementEntity;
import com.biznext.erp.inventory.InventoryMovementRequest;
import com.biznext.erp.inventory.InventoryMovementRepository;
import com.biznext.erp.inventory.InventoryMovementService;
import com.biznext.erp.inventory.InventoryMovementType;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class InventoryMovementServiceTest {
    @Mock
    private InventoryMovementRepository repository;

    @InjectMocks
    private InventoryMovementService service;

    @Test
    void shouldRejectStockOutWhenStockIsInsufficient() {
        InventoryMovementEntity movement = new InventoryMovementEntity(1L, 2L, 1L, InventoryMovementType.STOCK_IN, 20.0, 10.0, "PO", 100L, "system", "initial stock");
        when(repository.searchMovements(1L, 2L, 1L, null, null)).thenReturn(List.of(movement));

        ApiException exception = assertThrows(ApiException.class, () ->
                service.createMovement(new InventoryMovementRequest(1L, 2L, 1L, InventoryMovementType.STOCK_OUT, 25.0, 10.0, "SO", 200L, "system", "outbound"))
        );

        assertEquals("Insufficient stock available for this movement.", exception.getMessage());
    }
}
