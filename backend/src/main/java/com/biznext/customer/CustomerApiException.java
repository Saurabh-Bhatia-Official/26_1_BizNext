package com.biznext.customer;

import org.springframework.http.HttpStatus;

public class CustomerApiException extends RuntimeException {
    private final HttpStatus status;

    public CustomerApiException(String message) {
        this(message, HttpStatus.BAD_REQUEST);
    }

    public CustomerApiException(String message, HttpStatus status) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}
