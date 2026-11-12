package com.biznext.customer;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/customers")
public class CustomerController {

    private final CustomerService customerService;

    public CustomerController(CustomerService customerService) {
        this.customerService = customerService;
    }

    @GetMapping
    public CustomerPageResponse getAllCustomers(@RequestParam Long businessId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return CustomerPageResponse.from(customerService.getAllCustomers(businessId, pageable(page, size)));
    }

    @GetMapping("/{id}")
    public CustomerResponse getCustomerById(@PathVariable Long id, @RequestParam Long businessId) {
        return customerService.getCustomerById(businessId, id);
    }

    @GetMapping("/search")
    public CustomerPageResponse searchCustomers(@RequestParam Long businessId, @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return CustomerPageResponse.from(customerService.searchCustomers(businessId, q, pageable(page, size)));
    }

    @GetMapping("/filter")
    public CustomerPageResponse filterCustomers(
            @RequestParam Long businessId,
            @RequestParam(required = false) String name,
            @RequestParam(required = false) String phone,
            @RequestParam(required = false) String email,
            @RequestParam(required = false) Long customerTypeId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return CustomerPageResponse.from(customerService.filterCustomers(
            businessId, name, phone, email, customerTypeId, pageable(page, size)));
    }

    @PostMapping
    public ResponseEntity<CustomerResponse> createCustomer(@Valid @RequestBody CustomerRequest request) {
        CustomerResponse response = customerService.createCustomer(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PutMapping("/{id}")
    public CustomerResponse updateCustomer(@PathVariable Long id, @Valid @RequestBody CustomerRequest request) {
        return customerService.updateCustomer(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteCustomer(@PathVariable Long id, @RequestParam Long businessId) {
        customerService.deleteCustomer(businessId, id);
        return ResponseEntity.noContent().build();
    }

    private Pageable pageable(int page, int size) {
        if (page < 0 || size < 1 || size > 200) {
            throw new CustomerApiException("page must be non-negative and size must be between 1 and 200.");
        }
        return PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "name"));
    }
}
