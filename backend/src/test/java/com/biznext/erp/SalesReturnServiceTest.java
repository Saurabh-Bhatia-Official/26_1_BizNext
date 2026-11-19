package com.biznext.erp;

import com.biznext.erp.inventory.InventoryMovementService;
import com.biznext.erp.returns.ReturnItemRequest;
import com.biznext.erp.returns.SalesReturnRepository;
import com.biznext.erp.returns.SalesReturnRequest;
import com.biznext.erp.returns.SalesReturnService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@ExtendWith(MockitoExtension.class)
class SalesReturnServiceTest {
    @Mock
    private SalesReturnRepository repository;

    @Mock
    private InventoryMovementService inventoryMovementService;

    @InjectMocks
    private SalesReturnService service;

    @Test
    void shouldRejectReturnQuantityGreaterThanOriginalInvoiceQuantity() {
        SalesReturnRequest request = new SalesReturnRequest(
                1L,
                10L,
                20L,
                "Damaged goods",
                90L,
                "admin",
                List.of(new ReturnItemRequest(5L, 4.0, 100.0, "Damage", 3.0))
        );

        ApiException exception = assertThrows(ApiException.class, () -> service.createReturn(request));
        assertEquals("Return quantity cannot exceed the original invoice quantity.", exception.getMessage());
    }
}
