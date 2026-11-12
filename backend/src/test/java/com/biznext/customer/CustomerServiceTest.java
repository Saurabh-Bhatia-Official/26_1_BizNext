package com.biznext.customer;

import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class CustomerServiceTest {

    private final CustomerRepository customerRepository = mock(CustomerRepository.class);
    private final SalesRepository salesRepository = mock(SalesRepository.class);
    private final LedgerRepository ledgerRepository = mock(LedgerRepository.class);
    private final CustomerService customerService = new CustomerService(customerRepository, salesRepository, ledgerRepository);

    @Test
    void createCustomer_shouldRejectDuplicatePhonePerBusiness() {
        CustomerRequest request = new CustomerRequest(
                1L,
                "Alice Johnson",
                "9876543210",
                "alice@example.com",
                "Street One",
                "GST123",
                2L,
                0.0,
                0.0
        );

        CustomerEntity existing = new CustomerEntity();
        existing.setId(11L);
        existing.setBusinessId(1L);
        existing.setPhone("9876543210");

        when(customerRepository.findByBusinessIdAndPhoneNormalized(1L, "9876543210")).thenReturn(Optional.of(existing));

        CustomerApiException exception = assertThrows(CustomerApiException.class, () -> customerService.createCustomer(request));
        assertTrue(exception.getMessage().contains("already exists"));
    }

    @Test
    void deleteCustomer_shouldRejectWhenSalesExist() {
        CustomerEntity customer = new CustomerEntity();
        customer.setId(22L);
        customer.setBusinessId(1L);
        customer.setName("Linked Customer");

        when(customerRepository.findByIdAndBusinessId(22L, 1L)).thenReturn(Optional.of(customer));
        when(salesRepository.existsByBusinessIdAndCustomerId(1L, 22L)).thenReturn(true);

        CustomerApiException exception = assertThrows(CustomerApiException.class, () -> customerService.deleteCustomer(1L, 22L));
        assertTrue(exception.getMessage().contains("cannot be deleted"));
    }
}
