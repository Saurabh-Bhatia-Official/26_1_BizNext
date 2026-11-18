package com.biznext.erp;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, Object>> handleApiException(ApiException ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("message", ex.getMessage());
        body.put("status", ex.getStatus().value());
        return ResponseEntity.status(ex.getStatus()).body(body);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException ex) {
        Map<String, Object> body = new HashMap<>();
        FieldError fieldError = ex.getBindingResult().getFieldErrors().stream().findFirst().orElse(null);
        body.put("message", fieldError == null ? "Validation failed." : fieldError.getDefaultMessage());
        body.put("status", HttpStatus.BAD_REQUEST.value());
        return ResponseEntity.badRequest().body(body);
    }
}
