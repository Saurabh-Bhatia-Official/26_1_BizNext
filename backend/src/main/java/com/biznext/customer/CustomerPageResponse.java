package com.biznext.customer;

import org.springframework.data.domain.Page;

import java.util.List;

public record CustomerPageResponse(
        List<CustomerResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages,
        boolean last
) {
    public static CustomerPageResponse from(Page<CustomerResponse> source) {
        return new CustomerPageResponse(
                source.getContent(),
                source.getNumber(),
                source.getSize(),
                source.getTotalElements(),
                source.getTotalPages(),
                source.isLast()
        );
    }
}
