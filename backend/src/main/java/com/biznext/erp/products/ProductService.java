package com.biznext.erp.products;

import com.biznext.erp.ApiException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
public class ProductService {
    private static final Logger logger = LoggerFactory.getLogger(ProductService.class);
    private static final Set<String> SORT_FIELDS = Set.of("productName", "sellingPrice", "createdAt");

    private final ProductRepository products;
    private final ProductCategoryRepository categories;
    private final CloudinaryProductStorage imageStorage;
    private final JdbcTemplate jdbcTemplate;

    public ProductService(ProductRepository products, ProductCategoryRepository categories,
                          CloudinaryProductStorage imageStorage, JdbcTemplate jdbcTemplate) {
        this.products = products;
        this.categories = categories;
        this.imageStorage = imageStorage;
        this.jdbcTemplate = jdbcTemplate;
    }

    public Page<ProductEntity> getProducts(Long businessId, String query, Long categoryId, String brand,
                                           String status, boolean lowStockOnly, int page, int size,
                                           String sortBy, String direction) {
        requireBusinessId(businessId);
        if (page < 0 || size < 1 || size > 200) {
            throw new ApiException("page must be non-negative and size must be between 1 and 200.");
        }
        String sortField = normalizeSortField(sortBy);
        Sort.Direction sortDirection;
        try {
            sortDirection = Sort.Direction.fromString(direction);
        } catch (IllegalArgumentException exception) {
            throw new ApiException("direction must be ASC or DESC.");
        }
        Boolean active = parseStatus(status);
        String normalizedQuery = emptyToNull(query);
        String normalizedBrand = emptyToNull(brand);
        Pageable pageable = PageRequest.of(page, size,
                Sort.by(sortDirection, sortField).and(Sort.by(Sort.Direction.ASC, "id")));
        return products.findProducts(businessId, normalizedQuery, categoryId, normalizedBrand,
                active, lowStockOnly, pageable);
    }

    public ProductEntity getProduct(Long businessId, Long id) {
        requireBusinessId(businessId);
        return findProduct(businessId, id);
    }

    @Transactional
    public ProductEntity create(ProductRequest request, MultipartFile image) {
        validateCategory(request.businessId(), request.categoryId());
        validateSku(request.businessId(), request.sku(), null);
        CloudinaryProductStorage.UploadedImage uploaded = image == null || image.isEmpty()
                ? null : imageStorage.upload(image);
        try {
            ProductEntity product = new ProductEntity(request.businessId(), request);
            if (uploaded != null) {
                product.setProductImage(uploaded.secureUrl(), uploaded.publicId());
            }
            ProductEntity saved = products.saveAndFlush(product);
            scheduleRollbackImageCleanup(uploaded);
            return products.findByIdAndBusinessId(saved.getId(), saved.getBusinessId()).orElse(saved);
        } catch (RuntimeException exception) {
            deleteUploadedImage(uploaded);
            throw translateDuplicate(exception);
        }
    }

    @Transactional
    public ProductEntity update(Long id, ProductRequest request, MultipartFile image, boolean removeImage) {
        ProductEntity existing = findProduct(request.businessId(), id);
        validateCategory(request.businessId(), request.categoryId());
        validateSku(request.businessId(), request.sku(), id);

        String previousImagePublicId = existing.getProductImagePublicId();
        java.math.BigDecimal stock = existing.getStockQuantity();
        CloudinaryProductStorage.UploadedImage uploaded = image == null || image.isEmpty()
                ? null : imageStorage.upload(image);
        try {
            existing.apply(request);
            existing.setStockQuantity(stock);
            if (uploaded != null) {
                existing.setProductImage(uploaded.secureUrl(), uploaded.publicId());
            } else if (removeImage) {
                existing.setProductImage(null, null);
            }
            ProductEntity saved = products.saveAndFlush(existing);
            scheduleRollbackImageCleanup(uploaded);
            if (uploaded != null || removeImage) {
                scheduleImageCleanup(previousImagePublicId);
            }
            return products.findByIdAndBusinessId(saved.getId(), saved.getBusinessId()).orElse(saved);
        } catch (RuntimeException exception) {
            deleteUploadedImage(uploaded);
            throw translateDuplicate(exception);
        }
    }

    @Transactional
    public void delete(Long businessId, Long id) {
        ProductEntity existing = findProduct(businessId, id);
        long dependents = countProductReferences(id);
        if (dependents > 0) {
            throw new ApiException(
                    "This product cannot be deleted because it has inventory or return history.",
                    HttpStatus.CONFLICT);
        }
        products.delete(existing);
        scheduleImageCleanup(existing.getProductImagePublicId());
    }

    @Transactional
    public ProductEntity updateStatus(Long businessId, Long id, ProductStatusRequest request) {
        ProductEntity existing = findProduct(businessId, id);
        String status = request.status().trim().toLowerCase(Locale.ROOT);
        if (!status.equals("active") && !status.equals("inactive")) {
            throw new ApiException("status must be Active or Inactive.");
        }
        existing.setActive(status.equals("active"));
        return products.save(existing);
    }

    @Transactional
    public ProductEntity adjustStock(Long id, ProductStockAdjustmentRequest request) {
        ProductEntity product = findProduct(request.businessId(), id);
        if (request.adjustedQuantity().compareTo(java.math.BigDecimal.ZERO) == 0) {
            throw new ApiException("Stock adjustment must be greater than zero.");
        }
        java.math.BigDecimal updatedStock = product.getStockQuantity().add(request.adjustedQuantity());
        if (updatedStock.compareTo(java.math.BigDecimal.ZERO) < 0) {
            throw new ApiException("Stock adjustment would result in negative stock.", HttpStatus.CONFLICT);
        }

        product.setStockQuantity(updatedStock);
        ProductEntity saved = products.saveAndFlush(product);
        jdbcTemplate.update("""
                INSERT INTO inventory_movements
                    (business_id, product_id, warehouse_id, movement_type, quantity, unit_cost, reference_type, note)
                VALUES (?, ?, 1, 'ADJUSTMENT', ?, ?, ?, ?)
                """,
                product.getBusinessId(), product.getId(), request.adjustedQuantity().doubleValue(),
                product.getPurchasePrice().doubleValue(), request.adjustmentType().trim(),
                request.reason().trim());
        return saved;
    }

    @Transactional
    public ProductCategoryEntity createCategory(ProductCategoryRequest request) {
        if (categories.existsByBusinessIdAndNameIgnoreCase(request.businessId(), request.name().trim())) {
            throw new ApiException("A product category with this name already exists.", HttpStatus.CONFLICT);
        }
        return categories.saveAndFlush(new ProductCategoryEntity(request.businessId(), request.name().trim()));
    }

    public List<ProductCategoryEntity> getCategories(Long businessId) {
        requireBusinessId(businessId);
        return categories.findAllByBusinessIdAndActiveTrueOrderByNameAsc(businessId);
    }

    @Transactional
    public ProductCategoryEntity updateCategory(Long businessId, Long id, ProductCategoryRequest request) {
        if (!businessId.equals(request.businessId())) {
            throw new ApiException("Product category cannot be moved to another business.");
        }
        ProductCategoryEntity category = categories.findByIdAndBusinessId(id, businessId)
                .orElseThrow(() -> new ApiException("Product category not found.", HttpStatus.NOT_FOUND));
        String name = request.name().trim();
        if (!category.getName().equalsIgnoreCase(name)
                && categories.existsByBusinessIdAndNameIgnoreCase(businessId, name)) {
            throw new ApiException("A product category with this name already exists.", HttpStatus.CONFLICT);
        }
        category.rename(name);
        return categories.saveAndFlush(category);
    }

    @Transactional
    public void deleteCategory(Long businessId, Long id) {
        requireBusinessId(businessId);
        ProductCategoryEntity category = categories.findByIdAndBusinessId(id, businessId)
                .orElseThrow(() -> new ApiException("Product category not found.", HttpStatus.NOT_FOUND));
        if (products.existsByBusinessIdAndCategoryId(businessId, id)) {
            throw new ApiException("This category cannot be deleted while products use it.", HttpStatus.CONFLICT);
        }
        categories.delete(category);
    }

    private ProductEntity findProduct(Long businessId, Long id) {
        return products.findByIdAndBusinessId(id, businessId)
                .orElseThrow(() -> new ApiException("Product not found.", HttpStatus.NOT_FOUND));
    }

    private void validateCategory(Long businessId, Long categoryId) {
        if (categoryId != null && categories.findByIdAndBusinessId(categoryId, businessId).isEmpty()) {
            throw new ApiException("Product category not found.", HttpStatus.BAD_REQUEST);
        }
    }

    private void validateSku(Long businessId, String sku, Long excludedId) {
        String normalizedSku = emptyToNull(sku);
        if (normalizedSku == null) return;
        boolean duplicate = products.existsByBusinessIdAndSkuIgnoreCase(businessId, normalizedSku);
        if (duplicate && (excludedId == null || products.findByIdAndBusinessId(excludedId, businessId)
                .map(product -> !normalizedSku.equalsIgnoreCase(product.getSku()))
                .orElse(true))) {
            throw new ApiException("A product with this SKU already exists.", HttpStatus.CONFLICT);
        }
    }

    private long countProductReferences(Long productId) {
        return jdbcTemplate.queryForObject("""
                SELECT
                    (SELECT COUNT(*) FROM inventory_movements WHERE product_id = ?) +
                    (SELECT COUNT(*) FROM sales_return_items WHERE product_id = ?) +
                    (SELECT COUNT(*) FROM purchase_return_items WHERE product_id = ?)
                """, Long.class, productId, productId, productId);
    }

    private void scheduleImageCleanup(String publicId) {
        if (publicId == null || publicId.isBlank()) return;
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                try {
                    imageStorage.delete(publicId);
                } catch (RuntimeException exception) {
                    logger.warn("Cloudinary image cleanup failed after product transaction committed.");
                }
            }
        });
    }

    private void scheduleRollbackImageCleanup(CloudinaryProductStorage.UploadedImage uploaded) {
        if (uploaded == null || !TransactionSynchronizationManager.isSynchronizationActive()) return;
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                if (status != TransactionSynchronization.STATUS_COMMITTED) {
                    deleteUploadedImage(uploaded);
                }
            }
        });
    }

    private void deleteUploadedImage(CloudinaryProductStorage.UploadedImage uploaded) {
        if (uploaded == null) return;
        try {
            imageStorage.delete(uploaded.publicId());
        } catch (RuntimeException exception) {
            logger.warn("Cloudinary cleanup failed after product write failed.");
        }
    }

    private RuntimeException translateDuplicate(RuntimeException exception) {
        if (exception instanceof DataIntegrityViolationException) {
            return new ApiException("A product with this SKU already exists or a related record is invalid.",
                    HttpStatus.CONFLICT);
        }
        return exception;
    }

    private static void requireBusinessId(Long businessId) {
        if (businessId == null || businessId <= 0) {
            throw new ApiException("A valid business ID is required.");
        }
    }

    private static Boolean parseStatus(String status) {
        if (status == null || status.isBlank() || "all".equalsIgnoreCase(status)) return null;
        if ("active".equalsIgnoreCase(status)) return true;
        if ("inactive".equalsIgnoreCase(status)) return false;
        throw new ApiException("status must be Active, Inactive, or All.");
    }

    private static String normalizeSortField(String sortBy) {
        String field = switch (sortBy == null ? "" : sortBy.toLowerCase(Locale.ROOT)) {
            case "", "name", "product_name", "productname" -> "productName";
            case "price", "selling_price", "sellingprice" -> "sellingPrice";
            case "date", "created_at", "createdat" -> "createdAt";
            default -> throw new ApiException("sortBy must be name, price, or date.");
        };
        if (!SORT_FIELDS.contains(field)) throw new ApiException("Unsupported product sort field.");
        return field;
    }

    private static String emptyToNull(String value) {
        if (value == null || value.isBlank()) return null;
        return value.trim();
    }
}
