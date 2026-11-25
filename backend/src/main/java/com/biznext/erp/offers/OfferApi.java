package com.biznext.erp.offers;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

record OfferRequest(
        @NotNull Long businessId,
        @NotBlank String name,
        @NotBlank String offerType,
        @NotBlank String discountType,
        Double discountValue,
        Double minQty,
        Double minAmount,
        String applyTo,
        Long targetId,
        Double buyQty,
        Double getQty,
        LocalDateTime startDate,
        LocalDateTime endDate,
        Boolean active,
        String posterUrl,
        String posterPublicId
) {}

@RestController
@RequestMapping("/api/offers")
class OfferController {
    private final OfferRepository repository;

    OfferController(OfferRepository repository) { this.repository = repository; }

    @GetMapping
    List<OfferEntity> list(@RequestParam Long businessId) {
        return repository.findByBusinessIdOrderByCreatedAtDesc(businessId);
    }

    @PostMapping
    ResponseEntity<OfferEntity> create(@Valid @RequestBody OfferRequest request) {
        OfferEntity entity = new OfferEntity();
        apply(entity, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(repository.save(entity));
    }

    @PutMapping("/{id}")
    OfferEntity update(@PathVariable Long id, @RequestParam Long businessId,
                       @Valid @RequestBody OfferRequest request) {
        OfferEntity entity = repository.findByIdAndBusinessId(id, businessId)
                .orElseThrow();
        apply(entity, request);
        return repository.save(entity);
    }

    @DeleteMapping("/{id}")
    ResponseEntity<Void> delete(@PathVariable Long id,
                                @RequestParam(required = false) Long businessId) {
        OfferEntity entity = businessId == null
                ? repository.findById(id).orElseThrow()
                : repository.findByIdAndBusinessId(id, businessId).orElseThrow();
        repository.delete(entity);
        return ResponseEntity.noContent().build();
    }

    private static void apply(OfferEntity entity, OfferRequest request) {
        entity.setBusinessId(request.businessId());
        entity.setName(request.name());
        entity.setOfferType(request.offerType());
        entity.setDiscountType(request.discountType());
        entity.setDiscountValue(request.discountValue() == null ? BigDecimal.ZERO : BigDecimal.valueOf(request.discountValue()));
        entity.setMinQty(request.minQty() == null ? BigDecimal.ZERO : BigDecimal.valueOf(request.minQty()));
        entity.setMinAmount(request.minAmount() == null ? BigDecimal.ZERO : BigDecimal.valueOf(request.minAmount()));
        entity.setApplyTo(request.applyTo() == null ? "all" : request.applyTo());
        entity.setTargetId(request.targetId());
        entity.setBuyQty(request.buyQty() == null ? BigDecimal.ZERO : BigDecimal.valueOf(request.buyQty()));
        entity.setGetQty(request.getQty() == null ? BigDecimal.ZERO : BigDecimal.valueOf(request.getQty()));
        entity.setStartDate(request.startDate());
        entity.setEndDate(request.endDate());
        entity.setActive(request.active() == null || request.active());
        entity.setPosterUrl(request.posterUrl());
        entity.setPosterPublicId(request.posterPublicId());
    }
}
