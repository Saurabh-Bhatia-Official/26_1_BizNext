# Product Requirements Document (PRD)

## Inventory, Supplier Purchase & POS Pricing Management

### 1. Objective & System Overview

Build a robust, auditable, and resilient inventory and purchasing system for **BizNext** that maintains accurate stock and pricing consistency from the moment products are procured from suppliers until they are sold through the Point of Sale (POS) terminal.

The system enforces a closed-loop transactional pipeline:

$$\text{Supplier} \longrightarrow \text{Purchase Entry} \longrightarrow \text{Stock Ledger \& WAC Costing} \longrightarrow \text{Tiered Pricing Engine} \longrightarrow \text{POS Billing} \longrightarrow \text{Sale Deduction} \longrightarrow \text{Audit \& Reports}$$

#### Key Problems Solved:
1. **Stock Discrepancy Prevention**: Stock quantities can never be manually overwritten from product editing screens; every movement is an immutable ledger entry.
2. **Pricing Integrity**: POS selling prices are dynamically computed based on customer classification, quantity-based tiered price lists, and configured discount rules.
3. **Minimum Price Protection**: Cashiers cannot sell below the product's minimum selling price without authenticated Manager Approval logged in the audit trail.
4. **Supplier Relationship Memory**: Tracks supplier purchase history, last purchase rate, supplier-specific SKUs, and outstanding balances.
5. **Accurate Inventory Valuation**: Real-time valuation using Weighted Average Cost (WAC) and FIFO principles.

---

### 2. Core Business Flow Architecture

```text
┌─────────────────┐       ┌────────────────────────┐       ┌─────────────────────────┐
│    Supplier     │ ────> │ Purchase Order / Entry │ ────> │  Stock Ledger Inflow    │
└─────────────────┘       └────────────────────────┘       │  • Qty In               │
                                                           │  • Weighted Avg Cost    │
                                                           │  • Warehouse Balance    │
                                                           └────────────┬────────────┘
                                                                        │
┌─────────────────┐       ┌────────────────────────┐                    ▼
│  Customer Type  │ ────> │ Tiered Pricing Engine  │ <──── ┌─────────────────────────┐
│ (Retail/Wholesale)      │ • Price List Rules     │       │     Product Master      │
└─────────────────┘       │ • Quantity Thresholds  │       │  • Reorder Levels       │
                          └───────────┬────────────┘       │  • Min Selling Price    │
                                      │                    └─────────────────────────┘
                                      ▼
┌─────────────────┐       ┌────────────────────────┐       ┌─────────────────────────┐
│   POS Billing   │ ────> │ Stock Ledger Outflow   │ ────> │ Financial & Stock Rpts  │
│ • Barcode/Search│       │ • Qty Out              │       │ • Valuation & Movement  │
│ • Min Price Auth│       │ • Sale Stock Deduction │       │ • Category & Price Sales│
└─────────────────┘       └────────────────────────┘       └─────────────────────────┘
```

---

### 3. Entity Data Dictionary & Database Schema

#### 3.1 Product Master (`products`)
| Field | Type | Constraint | Description |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY | Unique Product Identifier |
| `business_id` | INTEGER | NOT NULL | Multi-tenant Business Identifier |
| `name` | TEXT | NOT NULL | Product Title / Name |
| `sku` | TEXT | UNIQUE per biz | Stock Keeping Unit |
| `barcode` | TEXT | INDEXED | EAN / UPC / Custom Barcode |
| `category_id` | INTEGER | FK -> categories | Primary Category ID |
| `subcategory_id` | INTEGER | FK -> subcategories | Optional Subcategory ID |
| `brand` | TEXT | NULLABLE | Brand / Manufacturer Name |
| `unit` | TEXT | NOT NULL | Unit of Measure (pcs, kg, l, box, etc.) |
| `hsn_sac` | TEXT | NULLABLE | HSN/SAC Code for GST Compliance |
| `gst_percent` | REAL | NOT NULL DEFAULT 0 | Applicable GST Tax Rate (0, 5, 12, 18, 28) |
| `purchase_price` | REAL | NOT NULL DEFAULT 0 | Weighted Average Cost (WAC) / Cost Price |
| `mrp` | REAL | NOT NULL DEFAULT 0 | Maximum Retail Price |
| `selling_price` | REAL | NOT NULL DEFAULT 0 | Base Retail Selling Price |
| `min_selling_price`| REAL | NOT NULL DEFAULT 0 | Absolute Floor Price (Requires Manager Override) |
| `stock` | REAL | NOT NULL DEFAULT 0 | Current Calculated Stock |
| `min_stock` | REAL | NOT NULL DEFAULT 5 | Reorder Threshold / Alert Level |
| `default_supplier_id` | INTEGER | FK -> suppliers | Default/Primary Supplier |
| `is_active` | INTEGER | NOT NULL DEFAULT 1 | 1 = Active, 0 = Inactive |
| `image_path` | TEXT | NULLABLE | Product Image Local Filepath |

#### 3.2 Category & Subcategory Master (`categories`, `subcategories`)
- `categories`: `id`, `business_id`, `name`, `code`, `description`, `image_path`, `display_order`, `is_active`.
- `subcategories`: `id`, `business_id`, `category_id`, `name`, `code`, `description`, `is_active`.
- **Rule**: Only categories and subcategories where `is_active = 1` appear in the POS selector.

#### 3.3 Supplier Master & Mapping (`suppliers`, `supplier_products`)
- `suppliers`: `id`, `business_id`, `name`, `company_name`, `gstin`, `pan`, `contact_person`, `phone`, `email`, `address`, `state`, `payment_terms`, `credit_limit`, `opening_balance`, `balance`, `bank_details`, `notes`, `is_active`.
- `supplier_products`: `id`, `business_id`, `supplier_id`, `product_id`, `supplier_sku`, `supplier_barcode`, `last_purchase_price`, `last_purchase_date`, `last_purchase_qty`.

#### 3.4 Tiered Price Lists & Customer Types (`customer_types`, `product_tiered_prices`)
- `customer_types`: `id`, `business_id`, `name` (Retail, Wholesale, Dealer, Distributor, Special), `code`, `description`, `is_active`.
- `product_tiered_prices`: `id`, `product_id`, `category_id` (Customer Type ID), `min_qty`, `max_qty`, `price`, `discount_percent`.

#### 3.5 Stock Movement Ledger (`inventory_transactions`)
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `product_id`: INTEGER NOT NULL (FK -> products)
- `warehouse_id`: INTEGER (FK -> warehouses)
- `transaction_type`: `OPENING_STOCK` | `PURCHASE` | `SALE` | `SALES_RETURN` | `PURCHASE_RETURN` | `STOCK_ADJUSTMENT` | `STOCK_TRANSFER` | `DAMAGE_WASTAGE`
- `reference_number`: TEXT NOT NULL (Invoice No / Bill No / Adjustment Ref)
- `quantity`: REAL NOT NULL (Positive for inflow, negative for outflow)
- `unit_cost`: REAL NOT NULL (Cost rate at time of transaction)
- `opening_stock`: REAL NOT NULL
- `closing_stock`: REAL NOT NULL
- `created_by`: INTEGER (User ID)
- `created_date`: TEXT NOT NULL
- `remarks`: TEXT

#### 3.6 Audit Trail (`audit_logs`)
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `user_id`: INTEGER
- `module`: `POS` | `INVENTORY` | `PURCHASES` | `PRICING`
- `action_type`: `PRICE_OVERRIDE` | `STOCK_ADJUSTMENT` | `DISCOUNT_OVERRIDE` | `RETURN_APPROVAL`
- `record_id`: INTEGER
- `previous_state`: TEXT (JSON)
- `new_state`: TEXT (JSON)
- `remarks`: TEXT (e.g. "Manager approved selling below min price: ₹100 < ₹120")
- `timestamp`: TEXT NOT NULL

---

### 4. Detailed Functional Workflows

#### 4.1 Purchase Entry & Weighted Average Costing
1. User enters Purchase with Supplier, Supplier Invoice No, Payment Mode, Account, and Line Items.
2. For each line item:
   $$\text{New Stock} = \text{Current Stock} + \text{Purchased Qty}$$
   $$\text{New WAC Cost} = \frac{(\text{Current Stock} \times \text{Old Cost}) + (\text{Purchased Qty} \times \text{Purchase Rate})}{\text{New Stock}}$$
3. Update `products` table (`stock = New Stock`, `purchase_price = New WAC Cost`).
4. Update `supplier_products` with `last_purchase_price = Purchase Rate`, `last_purchase_date = now`, `last_purchase_qty = Qty`.
5. Post `PURCHASE` transaction into `inventory_transactions`.
6. Debit Inventory Asset, Debit Input GST, Credit Cash/Bank (or Credit Supplier Accounts Payable).

#### 4.2 POS Billing & Dynamic Pricing Resolution
1. **Product Scan / Selection**: Instant search by Barcode, SKU, or Name.
2. **Customer Type Evaluation**:
   - Walk-in / Retail customer $\rightarrow$ Retail Price Tier.
   - Wholesale customer $\rightarrow$ Wholesale Price Tier.
   - Quantity bracket evaluation $\rightarrow$ e.g. Wholesale 10+ units automatically selects quantity tier rate.
3. **Stock Level Validation**:
   - If requested qty > available stock and `allow_negative_stock = 0`, block item addition with a low-stock alert.
4. **Minimum Selling Price & Override Permission**:
   - If selling price $< \text{min\_selling\_price}$:
     - If user is Cashier, display **Manager Approval Required** dialog asking for Manager PIN/credentials.
     - On approval, record `PRICE_OVERRIDE` in `audit_logs` and allow checkout.
5. **Checkout & Stock Deduction**:
   - Insert `sales` and `sale_items`.
   - Post `SALE` transaction into `inventory_transactions` with `opening_stock` and `closing_stock`.
   - Deduct product stock and warehouse stock.

#### 4.3 Stock Adjustments & Returns
- **Stock Adjustment**:
  - Requires explicit reason (`Physical Discrepancy`, `Damage/Wastage`, `Internal Consumption`, `Expired Item`).
  - Creates `STOCK_ADJUSTMENT` or `DAMAGE_WASTAGE` transaction in `inventory_transactions`.
- **Purchase Return**:
  - Reverses stock, logs `PURCHASE_RETURN`, updates Supplier balance.
- **Sales Return**:
  - Inflows returned items, logs `SALES_RETURN`, refunds cash or credits customer account.

---

### 5. Reporting & Analytics Architecture

1. **Stock Movement Ledger Report**:
   - Chronological ledger showing every In, Out, Reference, User, and Running Balance.
2. **Category-wise & Subcategory-wise Sales Report**:
   - Breakdown of quantity sold and total revenue per category/subcategory.
3. **Price-list / Customer-type-wise Sales Report**:
   - Revenue contribution across Retail, Wholesale, Dealer, Distributor.
4. **Supplier Performance & Outstanding Report**:
   - Purchases, payments made, balances due, and purchase returns per vendor.
5. **Stock Valuation & Risk Alerts**:
   - Total inventory value (WAC basis).
   - Low stock alerts ($stock \le reorder\_level$).
   - Out-of-stock alerts ($stock \le 0$).

---

### 6. Role-Based Access Control (RBAC)

| Role | POS Billing | Change Base Price | Sell Below Min Price | Record Purchases | Stock Adjustment | View Reports |
|---|---|---|---|---|---|---|
| **Owner / Admin** | Yes | Yes | Yes (Direct) | Yes | Yes | Full Access |
| **Manager** | Yes | Yes | Yes (Direct) | Yes | Yes | Full Access |
| **Purchase Manager** | No | No | No | Yes | View Only | Purchase Reports |
| **Inventory Manager**| No | No | No | View Only | Yes | Stock Reports |
| **Cashier** | Yes | No | Approval Required | No | No | Daily POS Summary |
