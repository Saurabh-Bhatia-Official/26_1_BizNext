package com.biznext.customer;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;

import java.util.Optional;

@Service
public class CustomerService {

    private final CustomerRepository customerRepository;
    private final SalesRepository salesRepository;
    private final LedgerRepository ledgerRepository;

    public CustomerService(CustomerRepository customerRepository,
                          SalesRepository salesRepository,
                          LedgerRepository ledgerRepository) {
        this.customerRepository = customerRepository;
        this.salesRepository = salesRepository;
        this.ledgerRepository = ledgerRepository;
    }

    public Page<CustomerResponse> getAllCustomers(Long businessId, Pageable pageable) {
        return customerRepository.findByBusinessId(businessId, pageable).map(CustomerResponse::fromEntity);
    }

    public CustomerResponse getCustomerById(Long businessId, Long id) {
        return customerRepository.findByIdAndBusinessId(id, businessId)
                .map(CustomerResponse::fromEntity)
                .orElseThrow(() -> new CustomerApiException("Customer not found.", HttpStatus.NOT_FOUND));
    }

    public Page<CustomerResponse> searchCustomers(Long businessId, String query, Pageable pageable) {
        String normalizedQuery = query == null ? "" : query.trim();
        if (normalizedQuery.isEmpty()) {
            return getAllCustomers(businessId, pageable);
        }
        return customerRepository.searchCustomers(businessId, normalizedQuery,
                normalizePhone(normalizedQuery), pageable).map(CustomerResponse::fromEntity);
    }

    public Page<CustomerResponse> filterCustomers(Long businessId, String name, String phone, String email,
                                                   Long customerTypeId, Pageable pageable) {
        return customerRepository.filterCustomers(
                        businessId,
                        emptyToNull(name),
                        emptyToNull(normalizePhone(phone)),
                        emptyToNull(email),
                        customerTypeId,
                        pageable
                ).map(CustomerResponse::fromEntity);
    }

    @Transactional
    public CustomerResponse createCustomer(CustomerRequest request) {
        validateCustomer(request, null);

        CustomerEntity entity = new CustomerEntity(
                request.businessId(),
                request.name().trim(),
                normalizePhone(request.phone()),
                request.email() == null ? null : request.email().trim(),
                request.address() == null ? null : request.address().trim(),
                request.gstNumber() == null ? null : request.gstNumber().trim(),
                request.customerTypeId(),
                request.balance() == null ? 0.0 : request.balance(),
                request.loyaltyPoints() == null ? 0.0 : request.loyaltyPoints()
        );

        return CustomerResponse.fromEntity(customerRepository.save(entity));
    }

    @Transactional
    public CustomerResponse updateCustomer(Long id, CustomerRequest request) {
        CustomerEntity existing = customerRepository.findByIdAndBusinessId(id, request.businessId())
            .orElseThrow(() -> new CustomerApiException("Customer not found.", HttpStatus.NOT_FOUND));

        validateCustomer(request, id);

        existing.setName(request.name().trim());
        existing.setPhone(normalizePhone(request.phone()));
        existing.setEmail(request.email() == null ? null : request.email().trim());
        existing.setAddress(request.address() == null ? null : request.address().trim());
        existing.setGstNumber(request.gstNumber() == null ? null : request.gstNumber().trim());
        existing.setCustomerTypeId(request.customerTypeId());
        existing.setBalance(request.balance() == null ? 0.0 : request.balance());
        existing.setLoyaltyPoints(request.loyaltyPoints() == null ? 0.0 : request.loyaltyPoints());

        return CustomerResponse.fromEntity(customerRepository.save(existing));
    }

    @Transactional
    public void deleteCustomer(Long businessId, Long customerId) {
        CustomerEntity existing = customerRepository.findByIdAndBusinessId(customerId, businessId)
            .orElseThrow(() -> new CustomerApiException("Customer not found.", HttpStatus.NOT_FOUND));

        boolean hasSales = salesRepository.existsByBusinessIdAndCustomerId(businessId, customerId);
        boolean hasLedger = ledgerRepository.existsByBusinessIdAndEntityTypeAndEntityId(
            businessId, "customer", customerId);

        if (hasSales || hasLedger) {
                throw new CustomerApiException("This customer cannot be deleted because it has sales history or account ledger activity.",
                    HttpStatus.CONFLICT);
        }

        customerRepository.delete(existing);
    }

    private void validateCustomer(CustomerRequest request, Long ignoreId) {
        if (request.name() == null || request.name().trim().isEmpty()) {
            throw new CustomerApiException("Customer name is required.");
        }

        String normalizedPhone = normalizePhone(request.phone());
        if (normalizedPhone.isEmpty()) {
            throw new CustomerApiException("Mobile number is required.");
        }

        if (normalizedPhone.length() < 10 || normalizedPhone.length() > 15) {
            throw new CustomerApiException("Please enter a valid mobile number.");
        }

        Optional<CustomerEntity> duplicate = customerRepository.findByBusinessIdAndPhoneNormalized(
            request.businessId(), normalizedPhone);
        if (duplicate.isPresent() && (ignoreId == null || !duplicate.get().getId().equals(ignoreId))) {
            throw new CustomerApiException("A customer with this mobile number already exists for this business.",
                HttpStatus.CONFLICT);
        }
    }

    private static String normalizePhone(String rawPhone) {
        if (rawPhone == null) return "";
        return rawPhone.replaceAll("[^0-9]", "");
    }

    private static String emptyToNull(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
