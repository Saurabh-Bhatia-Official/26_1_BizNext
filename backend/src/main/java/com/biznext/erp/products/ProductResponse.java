package com.biznext.erp.products;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record ProductResponse(
        Long id,
        Long businessId,
        String productName,
        String sku,
        Long categoryId,
        String categoryName,
        String brand,
        String description,
        BigDecimal purchasePrice,
        BigDecimal mrp,
        BigDecimal sellingPrice,
        BigDecimal minSellingPrice,
        BigDecimal wholesalePrice,
        BigDecimal dealerPrice,
        BigDecimal taxPercentage,
        BigDecimal stockQuantity,
        BigDecimal minimumStockLevel,
        String unit,
        String barcode,
        String hsnSac,
        String productImage,
        String productImagePublicId,
        String status,
        boolean lowStock,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {
    public static ProductResponse from(ProductEntity product) {
        return new ProductResponse(
                product.getId(), product.getBusinessId(), product.getProductName(), product.getSku(),
                product.getCategoryId(),
                product.getCategory() == null ? null : product.getCategory().getName(),
                product.getBrand(), product.getDescription(),
                product.getPurchasePrice(), product.getMrp(), product.getSellingPrice(),
                product.getMinSellingPrice(), product.getWholesalePrice(), product.getDealerPrice(),
                product.getTaxPercentage(), product.getStockQuantity(), product.getMinimumStockLevel(),
                product.getUnit(), product.getBarcode(), product.getHsnSac(), product.getProductImage(),
                product.getProductImagePublicId(), product.isActive() ? "Active" : "Inactive",
                product.isLowStock(), product.getCreatedAt(), product.getUpdatedAt());
    }
}
