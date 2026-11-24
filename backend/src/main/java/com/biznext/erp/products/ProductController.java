package com.biznext.erp.products;

import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@Validated
@RequestMapping("/api/products")
public class ProductController {
    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping
    public ProductPageResponse getProducts(
            @RequestParam Long businessId,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) String brand,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "false") boolean lowStock,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(defaultValue = "name") String sortBy,
            @RequestParam(defaultValue = "asc") String direction) {
        return page(productService.getProducts(
                businessId, q, categoryId, brand, status, lowStock, page, size, sortBy, direction));
    }

    @GetMapping("/search")
    public ProductPageResponse searchProducts(
            @RequestParam Long businessId,
            @RequestParam String q,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) String brand,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(defaultValue = "name") String sortBy,
            @RequestParam(defaultValue = "asc") String direction) {
        return page(productService.getProducts(
                businessId, q, categoryId, brand, status, false, page, size, sortBy, direction));
    }

    @GetMapping("/category/{categoryId}")
    public ProductPageResponse getByCategory(
            @RequestParam Long businessId,
            @PathVariable Long categoryId,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String brand,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(defaultValue = "name") String sortBy,
            @RequestParam(defaultValue = "asc") String direction) {
        return page(productService.getProducts(
                businessId, q, categoryId, brand, status, false, page, size, sortBy, direction));
    }

    @GetMapping("/low-stock")
    public ProductPageResponse getLowStock(
            @RequestParam Long businessId,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) String brand,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(defaultValue = "name") String sortBy,
            @RequestParam(defaultValue = "asc") String direction) {
        return page(productService.getProducts(
                businessId, null, categoryId, brand, status, true, page, size, sortBy, direction));
    }

    @GetMapping("/categories")
    public List<ProductCategoryResponse> getCategories(@RequestParam Long businessId) {
        return productService.getCategories(businessId).stream().map(ProductCategoryResponse::from).toList();
    }

    @PostMapping("/categories")
    public ResponseEntity<ProductCategoryResponse> createCategory(
            @Valid @RequestBody ProductCategoryRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ProductCategoryResponse.from(productService.createCategory(request)));
    }

    @PutMapping("/categories/{id}")
    public ProductCategoryResponse updateCategory(
            @PathVariable Long id,
            @RequestParam Long businessId,
            @Valid @RequestBody ProductCategoryRequest request) {
        return ProductCategoryResponse.from(productService.updateCategory(businessId, id, request));
    }

    @DeleteMapping("/categories/{id}")
    public ResponseEntity<Void> deleteCategory(@PathVariable Long id, @RequestParam Long businessId) {
        productService.deleteCategory(businessId, id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}")
    public ProductResponse getProduct(@PathVariable Long id, @RequestParam Long businessId) {
        return ProductResponse.from(productService.getProduct(businessId, id));
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ProductResponse> createProduct(
            @Valid @RequestPart("product") ProductRequest request,
            @RequestPart(value = "image", required = false) MultipartFile image) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ProductResponse.from(productService.create(request, image)));
    }

    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ProductResponse updateProduct(
            @PathVariable Long id,
            @Valid @RequestPart("product") ProductRequest request,
            @RequestPart(value = "image", required = false) MultipartFile image,
            @RequestParam(defaultValue = "false") boolean removeImage) {
        return ProductResponse.from(productService.update(id, request, image, removeImage));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id, @RequestParam Long businessId) {
        productService.delete(businessId, id);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/status")
    public ProductResponse updateStatus(@PathVariable Long id, @RequestParam Long businessId,
                                        @Valid @RequestBody ProductStatusRequest request) {
        return ProductResponse.from(productService.updateStatus(businessId, id, request));
    }

    @PatchMapping("/{id}/stock")
    public ProductResponse adjustStock(@PathVariable Long id,
                                       @Valid @RequestBody ProductStockAdjustmentRequest request) {
        return ProductResponse.from(productService.adjustStock(id, request));
    }

    private static ProductPageResponse page(Page<ProductEntity> page) {
        return ProductPageResponse.from(page);
    }
}
