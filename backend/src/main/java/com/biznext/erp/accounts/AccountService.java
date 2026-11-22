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

    public AccountResponse updateAccount(Long businessId, Long id, AccountRequest request) {
        AccountEntity entity = repository.findById(id)
                .orElseThrow(() -> new ApiException("Account not found.", HttpStatus.NOT_FOUND));
        if (!businessId.equals(entity.getBusinessId())
                || !businessId.equals(request.businessId())) {
            throw new ApiException("Account does not belong to this business.", HttpStatus.BAD_REQUEST);
        }
        entity.setCode(request.code().trim());
        entity.setName(request.name().trim());
        entity.setType(request.type().trim());
        return AccountResponse.fromEntity(repository.save(entity));
    }

    public void deleteAccount(Long businessId, Long id) {
        AccountEntity entity = repository.findById(id)
                .orElseThrow(() -> new ApiException("Account not found.", HttpStatus.NOT_FOUND));
        if (!businessId.equals(entity.getBusinessId())) {
            throw new ApiException("Account does not belong to this business.", HttpStatus.BAD_REQUEST);
        }
        entity.setActive(false);
        repository.save(entity);
    }
}
