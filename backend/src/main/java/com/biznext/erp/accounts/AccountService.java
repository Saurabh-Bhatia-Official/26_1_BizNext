package com.biznext.erp.accounts;

import com.biznext.erp.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AccountService {
    private final AccountRepository repository;

    public AccountService(AccountRepository repository) {
        this.repository = repository;
    }

    public List<AccountResponse> getAccounts(Long businessId) {
        return repository.findByBusinessIdOrderByCodeAsc(businessId)
                .stream().map(AccountResponse::fromEntity).toList();
    }

    public AccountResponse createAccount(AccountRequest request) {
        if (request.businessId() == null || request.businessId() <= 0) {
            throw new ApiException("A valid business ID is required.", HttpStatus.BAD_REQUEST);
        }
        if (repository.existsByBusinessIdAndCode(request.businessId(), request.code().trim())) {
            throw new ApiException("Account code already exists for this business.", HttpStatus.CONFLICT);
        }
        AccountEntity entity = new AccountEntity(request.businessId(), request.code().trim(), request.name().trim(), request.type().trim());
        return AccountResponse.fromEntity(repository.save(entity));
    }
}
