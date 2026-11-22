package com.biznext.erp.offers;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface OfferRepository extends JpaRepository<OfferEntity, Long> {
    List<OfferEntity> findByBusinessIdOrderByCreatedAtDesc(Long businessId);
    Optional<OfferEntity> findByIdAndBusinessId(Long id, Long businessId);
}
