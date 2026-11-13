package com.biznext.customer;

import org.springframework.data.jpa.repository.JpaRepository;

public interface SalesRepository extends JpaRepository<SalesEntity, Long> {
    boolean existsByBusinessIdAndCustomerId(Long businessId, Long customerId);
    boolean existsByCustomerId(Long customerId);
}
