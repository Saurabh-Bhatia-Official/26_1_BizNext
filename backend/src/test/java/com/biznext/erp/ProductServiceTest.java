package com.biznext.erp;

import com.biznext.erp.products.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {
    @Mock
    private ProductRepository products;
    @Mock
    private ProductCategoryRepository categories;
    @Mock
    private CloudinaryProductStorage imageStorage;
    @Mock
    private JdbcTemplate jdbcTemplate;

    @InjectMocks
    private ProductService service;

    @Test
    void shouldRejectDuplicateSkuWithinBusiness() {
        when(products.existsByBusinessIdAndSkuIgnoreCase(1L, "RICE-1")).thenReturn(true);

        ApiException exception = assertThrows(ApiException.class,
                () -> service.create(request("RICE-1", BigDecimal.ZERO), null));

        assertEquals(HttpStatus.CONFLICT, exception.getStatus());
        verify(products, never()).saveAndFlush(any());
    }

    @Test
    void shouldSaveProductWithoutImage() {
        when(products.existsByBusinessIdAndSkuIgnoreCase(1L, "RICE-1")).thenReturn(false);
        when(products.saveAndFlush(any(ProductEntity.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        ProductEntity saved = service.create(request("RICE-1", BigDecimal.valueOf(8)), null);

        assertEquals("Rice", saved.getProductName());
        assertEquals(BigDecimal.valueOf(8), saved.getStockQuantity());
        assertNull(saved.getProductImage());
        verify(imageStorage, never()).upload(any());
    }

    @Test
    void shouldRemoveUploadedImageWhenDatabaseWriteFails() {
        CloudinaryProductStorage.UploadedImage image =
                new CloudinaryProductStorage.UploadedImage(
                        "https://res.cloudinary.com/demo/image/upload/a.jpg", "biznext/products/a");
        when(products.existsByBusinessIdAndSkuIgnoreCase(1L, "RICE-1")).thenReturn(false);
        when(imageStorage.upload(any())).thenReturn(image);
        when(products.saveAndFlush(any(ProductEntity.class)))
                .thenThrow(new DataIntegrityViolationException("duplicate"));

        assertThrows(ApiException.class,
                () -> service.create(request("RICE-1", BigDecimal.ZERO), mock(org.springframework.web.multipart.MultipartFile.class)));

        verify(imageStorage).delete("biznext/products/a");
    }

    @Test
    void shouldApplyStockAdjustmentTransactionally() {
        ProductEntity product = new ProductEntity(1L, request(null, BigDecimal.valueOf(5)));
        when(products.findByIdAndBusinessId(3L, 1L)).thenReturn(Optional.of(product));
        when(products.saveAndFlush(product)).thenReturn(product);

        ProductEntity updated = service.adjustStock(
                3L,
                new ProductStockAdjustmentRequest(
                        1L, BigDecimal.valueOf(-2), "DAMAGE", "Damaged during inspection"));

        assertEquals(BigDecimal.valueOf(3), updated.getStockQuantity());
        verify(jdbcTemplate).update(contains("INSERT INTO inventory_movements"), any(), any(),
                any(), any(), any(), any());
    }

    private static ProductRequest request(String sku, BigDecimal stock) {
        return new ProductRequest(
                1L, "Rice", sku, null, null, null,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ONE,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                stock, BigDecimal.valueOf(5), "kg", null, null, true);
    }
}
