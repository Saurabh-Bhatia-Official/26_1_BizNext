package com.biznext.customer;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Optional;

public interface CustomerRepository extends JpaRepository<CustomerEntity, Long> {

    List<CustomerEntity> findByBusinessIdOrderByNameAsc(Long businessId);

        Page<CustomerEntity> findByBusinessId(Long businessId, Pageable pageable);

        Optional<CustomerEntity> findByIdAndBusinessId(Long id, Long businessId);

        Optional<CustomerEntity> findByBusinessIdAndPhoneNormalized(Long businessId, String phoneNormalized);

    @Query("SELECT c FROM CustomerEntity c WHERE c.businessId = :businessId " +
            "AND (:name IS NULL OR LOWER(c.name) LIKE LOWER(CONCAT('%', :name, '%'))) " +
            "AND (:phone IS NULL OR c.phoneNormalized LIKE CONCAT('%', :phone, '%')) " +
            "AND (:email IS NULL OR LOWER(c.email) LIKE LOWER(CONCAT('%', :email, '%'))) " +
            "AND (:customerTypeId IS NULL OR c.customerTypeId = :customerTypeId) " +
            "ORDER BY c.name ASC")
    Page<CustomerEntity> filterCustomers(
            @Param("businessId") Long businessId,
            @Param("name") String name,
            @Param("phone") String phone,
            @Param("email") String email,
            @Param("customerTypeId") Long customerTypeId,
            Pageable pageable
    );

    @Query("SELECT c FROM CustomerEntity c WHERE c.businessId = :businessId " +
            "AND (LOWER(c.name) LIKE LOWER(CONCAT('%', :query, '%')) OR (:digits <> '' AND c.phoneNormalized LIKE CONCAT('%', :digits, '%'))) " +
            "ORDER BY c.name ASC")
    Page<CustomerEntity> searchCustomers(@Param("businessId") Long businessId,
                                         @Param("query") String query,
                                         @Param("digits") String digits,
                                         Pageable pageable);
}
