package com.biznext.erp.products;

public record ProductCategoryResponse(Long id, Long businessId, String name) {
    public static ProductCategoryResponse from(ProductCategoryEntity category) {
        return new ProductCategoryResponse(category.getId(), category.getBusinessId(), category.getName());
    }
}
