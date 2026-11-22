package com.biznext.erp.media;

import com.biznext.erp.products.CloudinaryProductStorage;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/media")
public class MediaController {
    private final CloudinaryProductStorage storage;

    public MediaController(CloudinaryProductStorage storage) {
        this.storage = storage;
    }

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Map<String, String>> upload(@RequestPart("file") MultipartFile file) {
        CloudinaryProductStorage.UploadedImage uploaded = storage.upload(file);
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
                "url", uploaded.secureUrl(),
                "publicId", uploaded.publicId()
        ));
    }

    @DeleteMapping
    public ResponseEntity<Void> delete(@RequestParam String publicId) {
        storage.delete(publicId);
        return ResponseEntity.noContent().build();
    }
}
