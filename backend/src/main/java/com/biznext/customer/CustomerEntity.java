package com.biznext.customer;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "customers")
public class CustomerEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "business_id", nullable = false)
    private Long businessId;

    @Column(nullable = false)
    private String name;

    private String phone;

    @Column(name = "phone_normalized", insertable = false, updatable = false)
    private String phoneNormalized;
    private String email;
    private String address;

    @Column(name = "gst_number")
    private String gstNumber;

    @Column(name = "customer_type_id")
    private Long customerTypeId;

    @Column(nullable = false)
    private Double balance = 0.0;

    @Column(name = "loyalty_points", nullable = false)
    private Double loyaltyPoints = 0.0;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public CustomerEntity() {
    }

    public CustomerEntity(Long businessId, String name, String phone, String email, String address,
                         String gstNumber, Long customerTypeId, Double balance, Double loyaltyPoints) {
        this.businessId = businessId;
        this.name = name;
        this.phone = phone;
        this.email = email;
        this.address = address;
        this.gstNumber = gstNumber;
        this.customerTypeId = customerTypeId;
        this.balance = balance == null ? 0.0 : balance;
        this.loyaltyPoints = loyaltyPoints == null ? 0.0 : loyaltyPoints;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getBusinessId() { return businessId; }
    public void setBusinessId(Long businessId) { this.businessId = businessId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getPhoneNormalized() { return phoneNormalized; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }

    public String getGstNumber() { return gstNumber; }
    public void setGstNumber(String gstNumber) { this.gstNumber = gstNumber; }

    public Long getCustomerTypeId() { return customerTypeId; }
    public void setCustomerTypeId(Long customerTypeId) { this.customerTypeId = customerTypeId; }

    public Double getBalance() { return balance; }
    public void setBalance(Double balance) { this.balance = balance == null ? 0.0 : balance; }

    public Double getLoyaltyPoints() { return loyaltyPoints; }
    public void setLoyaltyPoints(Double loyaltyPoints) { this.loyaltyPoints = loyaltyPoints == null ? 0.0 : loyaltyPoints; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
