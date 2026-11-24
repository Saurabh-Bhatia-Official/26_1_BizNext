package com.biznext.erp.products;

import com.biznext.erp.ApiException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;

@Service
public class CloudinaryProductStorage {
    private static final Logger logger = LoggerFactory.getLogger(CloudinaryProductStorage.class);
    private static final long MAX_IMAGE_SIZE = 5 * 1024 * 1024;
    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${CLOUDINARY_CLOUD_NAME:}")
    private String cloudName;

    @Value("${CLOUDINARY_API_KEY:}")
    private String apiKey;

    @Value("${CLOUDINARY_API_SECRET:}")
    private String apiSecret;

    @Value("${CLOUDINARY_UPLOAD_PRESET:ml_default}")
    private String uploadPreset;

    public UploadedImage upload(MultipartFile file) {
        validateImage(file);
        ensureConfigured();

        String publicId = "biznext/products/" + UUID.randomUUID();
        long timestamp = Instant.now().getEpochSecond();
        MultiValueMap<String, Object> fields = signedFields(
                Map.of("folder", "biznext/products", "public_id", publicId, "timestamp", Long.toString(timestamp)));
        try {
            byte[] content = file.getBytes();
            fields.add("file", new ByteArrayResource(content) {
                @Override
                public String getFilename() {
                    return safeFilename(file.getOriginalFilename());
                }
            });
            ResponseEntity<Map> response;
            try {
                response = restTemplate.postForEntity(endpoint("image/upload"),
                        new HttpEntity<>(fields, multipartHeaders()), Map.class);
            } catch (HttpStatusCodeException exception) {
                if (exception.getStatusCode().value() == 403) {
                    logger.info("Signed upload not permitted for current API key role, using upload preset '{}'.", getUploadPreset());
                    MultiValueMap<String, Object> presetFields = new LinkedMultiValueMap<>();
                    presetFields.add("file", new ByteArrayResource(content) {
                        @Override
                        public String getFilename() {
                            return safeFilename(file.getOriginalFilename());
                        }
                    });
                    presetFields.add("upload_preset", getUploadPreset());
                    response = restTemplate.postForEntity(endpoint("image/upload"),
                            new HttpEntity<>(presetFields, multipartHeaders()), Map.class);
                } else {
                    throw exception;
                }
            }

            Object secureUrl = response.getBody() == null ? null : response.getBody().get("secure_url");
            Object returnedPublicId = response.getBody() == null ? null : response.getBody().get("public_id");
            if (response.getStatusCode().isError() || !(secureUrl instanceof String url)
                    || !url.startsWith("https://res.cloudinary.com/")
                    || !(returnedPublicId instanceof String id)) {
                throw new ApiException("Image storage returned an invalid response.", HttpStatus.BAD_GATEWAY);
            }
            return new UploadedImage(url, id);
        } catch (HttpStatusCodeException exception) {
            logger.warn("Cloudinary image upload failed with status {}.", exception.getStatusCode().value());
            throw new ApiException("Product image upload failed.", HttpStatus.BAD_GATEWAY);
        } catch (IOException exception) {
            throw new ApiException("The selected product image could not be read.", HttpStatus.BAD_REQUEST);
        }
    }

    public void delete(String publicId) {
        if (publicId == null || publicId.isBlank()) return;
        ensureConfigured();
        long timestamp = Instant.now().getEpochSecond();
        MultiValueMap<String, Object> fields = signedFields(
                Map.of("public_id", publicId, "timestamp", Long.toString(timestamp), "invalidate", "true"));
        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(endpoint("image/destroy"),
                    new HttpEntity<>(fields, multipartHeaders()), Map.class);
            Object result = response.getBody() == null ? null : response.getBody().get("result");
            if (response.getStatusCode().isError()
                    || !(result instanceof String value)
                    || !("ok".equals(value) || "not found".equals(value))) {
                throw new ApiException("Product image cleanup failed.", HttpStatus.BAD_GATEWAY);
            }
        } catch (HttpStatusCodeException exception) {
            logger.warn("Cloudinary image deletion failed with status {}.", exception.getStatusCode().value());
            throw new ApiException("Product image cleanup failed.", HttpStatus.BAD_GATEWAY);
        }
    }

    private void validateImage(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new ApiException("Choose a product image to upload.");
        }
        if (file.getSize() > MAX_IMAGE_SIZE) {
            throw new ApiException("Product images must be 5 MB or smaller.");
        }

        String filename = safeFilename(file.getOriginalFilename()).toLowerCase();
        boolean extensionAllowed = filename.endsWith(".jpg") || filename.endsWith(".jpeg")
                || filename.endsWith(".png") || filename.endsWith(".webp");
        try {
            byte[] bytes = file.getBytes();
            boolean jpeg = bytes.length >= 3 && (bytes[0] & 0xff) == 0xff
                    && (bytes[1] & 0xff) == 0xd8 && (bytes[2] & 0xff) == 0xff;
            boolean png = bytes.length >= 8 && (bytes[0] & 0xff) == 0x89
                    && bytes[1] == 'P' && bytes[2] == 'N' && bytes[3] == 'G';
            boolean webp = bytes.length >= 12 && bytes[0] == 'R' && bytes[1] == 'I'
                    && bytes[2] == 'F' && bytes[3] == 'F' && bytes[8] == 'W'
                    && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P';
            if (!extensionAllowed || !(jpeg || png || webp)) {
                throw new ApiException("Product image must be a valid JPG, JPEG, PNG, or WEBP file.");
            }
        } catch (IOException exception) {
            throw new ApiException("The selected product image could not be read.", HttpStatus.BAD_REQUEST);
        }
    }

    private MultiValueMap<String, Object> signedFields(Map<String, String> parameters) {
        TreeMap<String, String> signingParameters = new TreeMap<>(parameters);
        String canonical = signingParameters.entrySet().stream()
                .map(entry -> entry.getKey() + "=" + entry.getValue())
                .reduce((first, second) -> first + "&" + second)
                .orElse("");
        LinkedMultiValueMap<String, Object> fields = new LinkedMultiValueMap<>();
        signingParameters.forEach(fields::add);
        fields.add("api_key", getApiKey());
        fields.add("signature", sha1(canonical + getApiSecret()));
        return fields;
    }

    private String endpoint(String action) {
        return "https://api.cloudinary.com/v1_1/" + getCloudName() + "/" + action;
    }

    private HttpHeaders multipartHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        return headers;
    }

    private void ensureConfigured() {
        if (getCloudName().isBlank() || getApiKey().isBlank() || getApiSecret().isBlank()) {
            throw new ApiException("Product image storage is not configured.", HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    private String getCloudName() {
        return clean(cloudName);
    }

    private String getApiKey() {
        return clean(apiKey);
    }

    private String getApiSecret() {
        return clean(apiSecret);
    }

    private String getUploadPreset() {
        String cleaned = clean(uploadPreset);
        return cleaned.isBlank() ? "ml_default" : cleaned;
    }

    private static String clean(String value) {
        if (value == null) return "";
        String cleaned = value.trim();
        if (cleaned.length() >= 2
                && ((cleaned.startsWith("\"") && cleaned.endsWith("\""))
                || (cleaned.startsWith("'") && cleaned.endsWith("'")))) {
            cleaned = cleaned.substring(1, cleaned.length() - 1).trim();
        }
        return cleaned;
    }

    private static String safeFilename(String filename) {
        if (filename == null || filename.isBlank()) return "product-image";
        return filename.replaceAll("[^A-Za-z0-9._-]", "_");
    }

    private static String sha1(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-1")
                    .digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-1 is unavailable.", exception);
        }
    }

    public record UploadedImage(String secureUrl, String publicId) {
    }
}
