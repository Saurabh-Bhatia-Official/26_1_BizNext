CREATE TABLE IF NOT EXISTS inventory_movements (
    id BIGSERIAL PRIMARY KEY,
    business_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    warehouse_id BIGINT NOT NULL,
    movement_type VARCHAR(32) NOT NULL,
    quantity DOUBLE PRECISION NOT NULL,
    unit_cost DOUBLE PRECISION DEFAULT 0,
    reference_type VARCHAR(64),
    reference_id BIGINT,
    created_by VARCHAR(128),
    note TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_business_product
    ON inventory_movements (business_id, product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_business_warehouse
    ON inventory_movements (business_id, warehouse_id, created_at DESC);

CREATE TABLE IF NOT EXISTS sales_returns (
    id BIGSERIAL PRIMARY KEY,
    business_id BIGINT NOT NULL,
    sales_invoice_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    reason TEXT,
    total_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    refund_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    reference_account_id BIGINT,
    created_by VARCHAR(128),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP WITHOUT TIME ZONE,
    rejected_at TIMESTAMP WITHOUT TIME ZONE
);

CREATE TABLE IF NOT EXISTS sales_return_items (
    id BIGSERIAL PRIMARY KEY,
    sales_return_id BIGINT NOT NULL REFERENCES sales_returns (id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL,
    quantity DOUBLE PRECISION NOT NULL,
    unit_price DOUBLE PRECISION NOT NULL,
    total_amount DOUBLE PRECISION NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchase_returns (
    id BIGSERIAL PRIMARY KEY,
    business_id BIGINT NOT NULL,
    purchase_invoice_id BIGINT NOT NULL,
    supplier_id BIGINT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    reason TEXT,
    total_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    credit_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    reference_account_id BIGINT,
    created_by VARCHAR(128),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP WITHOUT TIME ZONE,
    rejected_at TIMESTAMP WITHOUT TIME ZONE
);

CREATE TABLE IF NOT EXISTS purchase_return_items (
    id BIGSERIAL PRIMARY KEY,
    purchase_return_id BIGINT NOT NULL REFERENCES purchase_returns (id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL,
    quantity DOUBLE PRECISION NOT NULL,
    unit_price DOUBLE PRECISION NOT NULL,
    total_amount DOUBLE PRECISION NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id BIGSERIAL PRIMARY KEY,
    business_id BIGINT NOT NULL,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(64) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (business_id, code)
);

CREATE TABLE IF NOT EXISTS journal_entries (
    id BIGSERIAL PRIMARY KEY,
    business_id BIGINT NOT NULL,
    description TEXT,
    reference_type VARCHAR(64),
    reference_id BIGINT,
    status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    created_by VARCHAR(128),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    posted_at TIMESTAMP WITHOUT TIME ZONE
);

CREATE TABLE IF NOT EXISTS journal_entry_lines (
    id BIGSERIAL PRIMARY KEY,
    journal_entry_id BIGINT NOT NULL REFERENCES journal_entries (id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL,
    description TEXT,
    debit DOUBLE PRECISION NOT NULL DEFAULT 0,
    credit DOUBLE PRECISION NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ledger_entries (
    id BIGSERIAL PRIMARY KEY,
    business_id BIGINT NOT NULL,
    account_id BIGINT,
    entity_type VARCHAR(64),
    entity_id BIGINT,
    entry_type VARCHAR(16) NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    balance DOUBLE PRECISION NOT NULL,
    description TEXT,
    reference_type VARCHAR(64),
    reference_id BIGINT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    business_id BIGINT NOT NULL,
    user_name VARCHAR(255),
    module_name VARCHAR(128) NOT NULL,
    entity_type VARCHAR(128) NOT NULL,
    entity_id BIGINT,
    action VARCHAR(64) NOT NULL,
    previous_value TEXT,
    new_value TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_business_module
    ON audit_logs (business_id, module_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_date
    ON audit_logs (user_name, created_at DESC);
