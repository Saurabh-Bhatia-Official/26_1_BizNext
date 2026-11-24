package com.biznext.erp.products;

import org.springframework.data.domain.Page;

import java.util.List;

public record ProductPageResponse(
        List<ProductResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages,
        boolean last
) {
    public static ProductPageResponse from(Page<ProductEntity> page) {
        return new ProductPageResponse(
                page.getContent().stream().map(ProductResponse::from).toList(),
                page.getNumber(), page.getSize(), page.getTotalElements(),
                page.getTotalPages(), page.isLast());
    }
}
