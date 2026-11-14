# BizNext — Updated Purchase Management Flow

**Version:** 2.0  
**Status:** Proposed Corrected Specification  
**Purpose:** Functional, accounting, inventory, database, and UI specification for the Purchase Management System.

---

## 1. Purpose

This document replaces the ambiguous portions of the existing Purchase Model Architecture.

It defines a single, professional source of truth for:

- Purchase calculation
- Discount treatment
- GST calculation
- Payment handling
- Supplier payable
- Inventory inward
- Weighted Average Cost (WAC)
- Double-entry accounting
- Purchase returns
- Validation
- Database integrity
- Transaction atomicity
- Purchase UI flow

The original architecture uses a Header–Item model with `PurchaseModel` for the purchase voucher and `PurchaseItemModel` for its line items. The purchase subsystem also updates inventory, supplier information, WAC, and ledger records.

---

## 2. Current Purchase Architecture

### 2.1 Purchase Header

`PurchaseModel` represents the purchase voucher/invoice.

Important fields:

| Field | Purpose |
|---|---|
| `id` | Purchase primary key |
| `businessId` | Current business/tenant |
| `billNo` | Supplier invoice/bill number |
| `supplierId` | Supplier reference |
| `subtotal` | Gross value of purchase items |
| `discount` | Purchase discount |
| `gstAmount` | Total GST |
| `grandTotal` | Final invoice value |
| `paidAmount` | Amount paid immediately |
| `balanceDue` | Amount payable to supplier |
| `paymentMode` | Cash, Bank Transfer, UPI, Credit, etc. |
| `accountId` | Payment account when money is paid |
| `status` | Purchase lifecycle status |
| `date` | Purchase date/time |
| `items` | Purchase line items |

### 2.2 Purchase Item

`PurchaseItemModel` represents each purchased product.

| Field | Purpose |
|---|---|
| `productId` | Product reference |
| `productName` | Product name snapshot |
| `quantity` | Purchased quantity |
| `purchasePrice` | Supplier purchase rate |
| `gstPercent` | Applicable GST rate |
| `total` | Gross line value |
| `gstAmount` | GST for the line |

---

# 3. Problems in the Existing Flow

The existing specification contains several areas that must be corrected or made explicit.

## 3.1 Discount is not properly represented in accounting

The existing ledger specification posts:

- Inventory Asset = `subtotal`
- Input GST = `gstAmount`
- Cash/Bank = `paidAmount`
- Supplier Payable = `balanceDue`

However, `grandTotal` already subtracts the discount.

This can create an accounting imbalance.

### Existing example

- Subtotal = ₹10,000
- Discount = ₹500
- GST = ₹1,710
- Grand Total = ₹11,210
- Paid = ₹5,000
- Balance = ₹6,210

Existing debit:

`₹10,000 + ₹1,710 = ₹11,710`

Existing credit:

`₹5,000 + ₹6,210 = ₹11,210`

**Difference = ₹500**

The missing ₹500 is exactly the discount.

---

## 3.2 GST calculation with bill-level discount is unclear

The existing documentation calculates line GST from the line total but also allows a bill-level discount.

The system must explicitly define whether the discount is:

1. Pre-tax discount, or
2. Post-tax discount.

### Recommended default

Supplier purchase discount should be treated as a **pre-tax discount** unless the supplier invoice explicitly indicates otherwise.

Therefore:

`Gross Value → Discount → Taxable Value → GST → Grand Total`

---

## 3.3 WAC uses the gross purchase price

The existing WAC formula uses the inward purchase price directly.

If a supplier discount applies to inventory cost, using the gross price produces an incorrect inventory valuation.

The WAC calculation must use the **effective inventory unit cost**.

---

## 3.4 Purchase status and payment status are mixed

A purchase can be completed while its payment is:

- Unpaid
- Partially Paid
- Fully Paid

Therefore, one status field should not represent both concepts.

Use separate:

- **Purchase Status**
- **Payment Status**

---

## 3.5 Payment account rules are incomplete

The system must clearly distinguish:

- Fully paid purchase
- Partially paid purchase
- Fully credit purchase

A fully credit purchase does not require a cash/bank account.

A purchase with an immediate payment requires a payment account.

---

## 3.6 Supplier payable source of truth is unclear

Supplier outstanding should not depend only on a manually stored balance.

It should be derived from supplier transactions:

`Opening Payable + Credit Purchases - Supplier Payments - Purchase Returns ± Adjustments`

---

## 3.7 Purchase return flow needs more detail

The return process must support:

- Partial returns
- Original purchase reference
- Returned quantity
- GST reversal
- Inventory reversal
- Supplier payable reduction
- Supplier refund
- Credit note/reference
- Accounting reversal

---

## 3.8 Business isolation must be enforced

`businessId` must always come from the current business context.

A hard-coded/default tenant such as `business_id = 1` must not be relied upon for production multi-business operation.

---

## 3.9 Database and model naming should be standardized

Examples requiring consistency:

- Dart: `paidAmount`
- Database: `paid_amount`
- Dart: `purchasePrice`
- Database: `price`

Mappings can be retained, but they must be explicitly standardized and used consistently.

---

# 4. Correct Purchase Lifecycle

The complete purchase process should follow this sequence:

```text
Select Business
      ↓
Select Supplier
      ↓
Select Warehouse
      ↓
Add Products
      ↓
Enter Quantity + Purchase Rate
      ↓
Calculate Gross Line Values
      ↓
Apply Line Discounts
      ↓
Apply Bill Discount
      ↓
Calculate Net Taxable Value
      ↓
Calculate GST
      ↓
Calculate Grand Total
      ↓
Enter Payment
      ↓
Calculate Balance Due
      ↓
Determine Payment Status
      ↓
Validate Everything
      ↓
Save Purchase
      ↓
Update Inventory
      ↓
Update Warehouse Stock
      ↓
Update WAC
      ↓
Update Supplier Product History
      ↓
Update Payment Account
      ↓
Update Supplier Payable
      ↓
Create Balanced Ledger Entries
      ↓
Create Audit Records
      ↓
COMMIT
```

If any step fails, the complete purchase transaction must be rolled back.

---

# 5. Professional Purchase Calculation Model

## 5.1 Line calculation

For every item:

```text
Line Gross = Quantity × Purchase Rate
```

If line-level discount is supported:

```text
Line Taxable = Line Gross − Line Discount
```

GST:

```text
Line GST = Line Taxable × GST Rate ÷ 100
```

---

## 5.2 Bill-level calculation

```text
Gross Subtotal
= Sum of all Line Gross values
```

```text
Line Discount Total
= Sum of all Line Discounts
```

```text
Net Taxable Value
= Gross Subtotal − Line Discount Total − Bill Discount
```

```text
GST Amount
= GST calculated on the final taxable value
```

```text
Grand Total
= Net Taxable Value + GST Amount
```

The taxable value must never become negative.

---

# 6. Discount Policy

## Default rule

Supplier purchase discounts are treated as **pre-tax discounts**.

Example:

```text
Gross Purchase       ₹10,000
Discount               ₹500
-----------------------------
Taxable Value          ₹9,500
GST @ 18%              ₹1,710
-----------------------------
Grand Total           ₹11,210
```

The UI must make the discount treatment clear.

Do not silently mix pre-tax and post-tax discount calculations.

---

# 7. Payment Calculation

```text
Balance Due = Grand Total − Paid Amount
```

Default validation:

```text
Paid Amount >= 0
Paid Amount <= Grand Total
```

If the business needs to pay more than the invoice total, the extra amount must be recorded as a **Supplier Advance**, not as a negative purchase payable.

---

# 8. Payment Rules

| Situation | Payment Account | Supplier Payable |
|---|---|---|
| Fully Paid | Required | ₹0 |
| Partially Paid | Required | Remaining amount |
| Fully Credit | Not required | Full invoice amount |
| Supplier Advance | Separate advance transaction | Separate treatment |

### Payment mode rules

If:

`paidAmount > 0`

then:

- `accountId` is required
- Account must belong to the current business
- Account must be valid
- Available balance should be checked where liquidity enforcement is enabled

For a fully credit purchase:

- Payment account is not required
- Full grand total becomes Supplier Payable

---

# 9. Worked Example

Assume:

```text
Gross Subtotal       ₹10,000
Discount                ₹500
GST Rate                 18%
Paid Amount           ₹5,000
```

Calculation:

```text
Net Taxable Value = ₹10,000 − ₹500
                  = ₹9,500

GST = ₹9,500 × 18%
    = ₹1,710

Grand Total = ₹9,500 + ₹1,710
            = ₹11,210

Balance Due = ₹11,210 − ₹5,000
            = ₹6,210
```

---

# 10. Correct Double-Entry Accounting

For the above example:

| Account | Debit | Credit |
|---|---:|---:|
| Inventory Asset | ₹9,500 | |
| Input GST / ITC Asset | ₹1,710 | |
| Bank | | ₹5,000 |
| Supplier Payable | | ₹6,210 |
| **Total** | **₹11,210** | **₹11,210** |

The transaction is balanced.

### Important rule

```text
Total Debits = Total Credits
```

The repository must verify this before committing the transaction.

---

# 11. Alternative Discount Accounting

If the business wants supplier discounts to be tracked separately instead of reducing inventory cost, a dedicated **Purchase Discount** account can be introduced.

However, this must be an explicit accounting policy.

Do not simultaneously:

- Reduce the inventory amount
- And post the same discount to a separate discount account

unless the accounting design intentionally supports it.

---

# 12. Inventory and WAC

The purchase increases inventory.

### Master stock

```text
New Product Stock
= Existing Stock + Purchase Quantity
```

### Warehouse stock

```text
New Warehouse Stock
= Existing Warehouse Stock + Purchase Quantity
```

### WAC

Recommended:

```text
New WAC =
(
    Existing Quantity × Existing WAC
    +
    Inward Quantity × Effective Unit Cost
)
÷
(
    Existing Quantity + Inward Quantity
)
```

If existing stock is zero or negative:

```text
New WAC = Effective Unit Cost
```

### Effective Unit Cost

When the supplier discount belongs to inventory cost:

```text
Effective Unit Cost
= Net Inventory Cost ÷ Purchased Quantity
```

The system must not use the undiscounted gross rate for WAC in this case.

---

# 13. Landed Cost Extension

If BizNext later supports:

- Freight
- Transportation
- Loading/unloading
- Insurance
- Other directly attributable costs

the system should define a landed-cost policy.

Recommended model:

```text
Inventory Cost
= Net Purchase Cost
+ Capitalized Applicable Landed Costs
```

Only costs defined by the accounting policy should be included in WAC.

---

# 14. Inventory Audit Transaction

Every completed purchase should create an inventory transaction containing at minimum:

- Purchase ID
- Bill number
- Product ID
- Warehouse ID
- Transaction type = `purchase`
- Quantity
- Unit cost
- Opening stock
- Closing stock
- Transaction date/time

This provides an auditable stock history.

---

# 15. Supplier Product History

For every purchased product, update supplier-product history with:

- Supplier ID
- Product ID
- Last purchase price
- Effective purchase cost where applicable
- Last purchase date
- Last purchase quantity

Use an atomic upsert mechanism where appropriate.

---

# 16. Supplier Payable

Supplier payable should be transaction-driven.

Recommended calculation:

```text
Supplier Outstanding
=
Opening Payable
+ Credit Purchases
− Supplier Payments
− Purchase Returns
± Supplier Adjustments
```

The purchase screen should show the payable created by the current purchase separately from the supplier's previous outstanding balance.

Example:

```text
Previous Outstanding     ₹20,000
Current Purchase         ₹11,210
Paid Now                  ₹5,000
New Outstanding          ₹26,210
```

---

# 17. Purchase Status

Use separate statuses.

## Purchase Status

Recommended values:

```text
Draft
Completed
Cancelled
```

## Payment Status

Recommended values:

```text
Unpaid
Partially Paid
Paid
```

Optional:

```text
Supplier Advance
```

### Example

A purchase can have:

```text
Purchase Status: Completed
Payment Status: Partially Paid
```

This is clearer than using one status for both concepts.

---

# 18. Purchase Return Flow

A purchase return must reference the original purchase.

## Return process

```text
Select Original Purchase
        ↓
Select Product
        ↓
Enter Return Quantity
        ↓
Validate Returnable Quantity
        ↓
Calculate Return Taxable Value
        ↓
Calculate GST Reversal
        ↓
Calculate Return Total
        ↓
Reduce Inventory
        ↓
Reduce Warehouse Stock
        ↓
Reverse Applicable Inventory Cost
        ↓
Reduce Supplier Payable OR Record Supplier Refund
        ↓
Create GST Reversal
        ↓
Create Ledger Reversal
        ↓
Create Inventory Audit
        ↓
Save Return
```

### Return validation

Returned quantity must not exceed the available returnable quantity from the original purchase.

The original purchase record should not be overwritten.

Partial returns must be supported.

---

# 19. Supplier Refund vs Supplier Credit

A purchase return can be settled in two ways.

## Supplier Credit

The supplier reduces the amount payable.

Accounting effect:

```text
Supplier Payable decreases
```

## Supplier Refund

The supplier returns money.

Accounting effect:

```text
Bank/Cash increases
Supplier Payable or Return Settlement decreases
```

The system must record which settlement method was used.

---

# 20. GST Treatment on Returns

For a taxable purchase return:

- Reverse the applicable Input GST
- Use the return's taxable value
- Maintain the original GST rate/tax treatment where required
- Store the supplier credit note/debit note reference where applicable

The system should not simply delete the original GST entry.

A return should create a controlled reversal transaction.

---

# 21. Validation Rules

Before saving:

### Business

- Current business must be valid.
- All referenced records must belong to the current business.

### Supplier

- Supplier must exist.
- Supplier must belong to the current business.

### Warehouse

- Warehouse must exist.
- Warehouse must belong to the current business.

### Product

- Product must exist.
- Product must belong to the current business.

### Items

- At least one item is required.
- Quantity must be greater than zero.
- Purchase rate must be greater than or equal to zero.
- GST rate must be valid.
- Discount must not produce a negative taxable amount.

### Payment

- Paid amount must be greater than or equal to zero.
- Paid amount should not exceed grand total unless Supplier Advance is explicitly supported.
- Payment account is required when paid amount is greater than zero.
- Payment account must belong to the current business.

### Bill number

Where a supplier bill number is provided:

```text
Business + Supplier + Bill Number
```

should not be duplicated.

---

# 22. Database Integrity

## Business ID

Do not rely on:

```sql
business_id INTEGER NOT NULL DEFAULT 1
```

for production business isolation.

The application must explicitly provide the current business ID.

---

## Duplicate Bill Constraint

Application validation should be supplemented with a database-level uniqueness strategy where appropriate.

Recommended logical uniqueness:

```text
business_id + supplier_id + bill_no
```

Only apply this when `bill_no` is present and the business rules permit it.

---

# 23. Model and Database Naming

Use consistent persistence conventions.

Recommended:

| Application Model | Database |
|---|---|
| `businessId` | `business_id` |
| `supplierId` | `supplier_id` |
| `paidAmount` | `paid_amount` |
| `balanceDue` | `balance_due` |
| `paymentMode` | `payment_mode` |
| `purchasePrice` | `price` |
| `gstPercent` | `gst_percent` |
| `gstAmount` | `gst_amount` |

The mapping should be centralized and documented.

---

# 24. Money Precision

Accounting calculations must use a consistent rounding policy.

Define:

- Currency precision
- GST rounding
- Line-level rounding
- Invoice-level rounding
- WAC precision

Do not allow different modules to round the same transaction differently.

A single calculation service should ideally produce the purchase totals used by:

- UI
- Database
- Ledger
- Reports
- Returns

---

# 25. Atomic Transaction Boundary

The complete purchase operation must run inside one database transaction.

The following operations must succeed together:

1. Purchase header
2. Purchase items
3. Inventory master stock
4. Warehouse stock
5. Inventory transaction
6. WAC update
7. Supplier product history
8. Supplier payable
9. Payment account movement
10. Ledger entries
11. Audit trail

If any operation fails:

```text
ROLLBACK EVERYTHING
```

Never allow:

```text
Stock Updated
+
Ledger Failed
```

or:

```text
Payment Deducted
+
Purchase Save Failed
```

---

# 26. Recommended Purchase UI

## Step 1 — Supplier

Fields:

- Supplier
- Supplier Bill Number
- Purchase Date

Display:

- Previous Supplier Outstanding

---

## Step 2 — Warehouse

Select:

- Target Warehouse

---

## Step 3 — Items

Each row should contain:

- Product
- Quantity
- Purchase Rate
- Discount
- GST %
- Taxable Amount
- GST Amount
- Line Total

---

## Step 4 — Summary

Display clearly:

```text
Gross Subtotal
− Line Discounts
− Bill Discount
----------------
Net Taxable Value
+ GST
----------------
Grand Total
```

---

## Step 5 — Payment

Fields:

- Paid Amount
- Payment Mode
- Payment Account when required

Display:

```text
Grand Total
Paid Amount
Balance Due
Payment Status
```

---

## Step 6 — Review

Before final save, show:

- Supplier
- Bill number
- Warehouse
- Items
- Taxable value
- GST
- Grand total
- Paid amount
- Balance due
- Payment status

---

## Step 7 — Save

On confirmation:

```text
Validate
→ Begin Transaction
→ Save Purchase
→ Save Items
→ Update Stock
→ Update WAC
→ Update Supplier
→ Update Payment Account
→ Update Payable
→ Create Ledger
→ Create Audit
→ Commit
```

---

# 27. Reports Requirements

Purchase reports should use the same source calculations as the purchase module.

Reports should be able to distinguish:

- Gross purchase value
- Discount
- Taxable purchase value
- GST
- Grand total
- Paid amount
- Supplier payable
- Purchase returns
- Net purchase value

Do not use independently recalculated values that can disagree with the purchase transaction.

---

# 28. Cancellation Rules

A completed purchase must not simply be deleted.

Cancellation should:

1. Validate whether cancellation is allowed.
2. Reverse inventory.
3. Reverse WAC impact according to the supported inventory accounting method.
4. Reverse payable.
5. Reverse payment/account movement where applicable.
6. Reverse ledger entries.
7. Preserve an audit trail.
8. Mark the purchase as cancelled.

If the system cannot safely reverse a completed transaction, it should use a controlled reversal/adjustment workflow instead of deleting records.

---

# 29. Final End-to-End Flow

```text
SUPPLIER
   ↓
SUPPLIER BILL
   ↓
WAREHOUSE
   ↓
PRODUCT ITEMS
   ↓
QUANTITY × PURCHASE RATE
   ↓
GROSS SUBTOTAL
   ↓
DISCOUNTS
   ↓
NET TAXABLE VALUE
   ↓
GST
   ↓
GRAND TOTAL
   ↓
PAYMENT
   ↓
BALANCE DUE
   ↓
PAYMENT STATUS
   ↓
VALIDATION
   ↓
PURCHASE RECORD
   ↓
INVENTORY
   ↓
WAREHOUSE STOCK
   ↓
WAC
   ↓
SUPPLIER PRODUCT HISTORY
   ↓
PAYMENT ACCOUNT
   ↓
SUPPLIER PAYABLE
   ↓
DOUBLE-ENTRY LEDGER
   ↓
AUDIT LOG
   ↓
COMMIT
```

---

# 30. Acceptance Criteria

The implementation is considered correct only when all of the following are true:

- [ ] Purchase with discount produces balanced accounting.
- [ ] GST is calculated from the defined taxable base.
- [ ] Discount treatment is explicitly defined.
- [ ] WAC uses the correct effective inventory cost.
- [ ] Paid, unpaid, and partially paid purchases are correctly represented.
- [ ] Fully credit purchases do not require a payment account.
- [ ] Supplier payable is transaction-driven.
- [ ] Purchase returns support partial quantities.
- [ ] Purchase returns reverse GST correctly.
- [ ] Purchase returns update inventory correctly.
- [ ] Purchase returns update supplier payable/refund correctly.
- [ ] Inventory and accounting cannot become partially updated.
- [ ] All records are isolated to the current business.
- [ ] Duplicate supplier bills are prevented.
- [ ] Database/model naming is consistent.
- [ ] Money rounding is consistent across modules.
- [ ] Completed purchases are not silently deleted.
- [ ] Existing valid data is not deleted or reset during implementation.
- [ ] UI exposes the required calculations clearly.
- [ ] Reports use the same purchase calculation source of truth.

---

# 31. Developer Implementation Principle

The Purchase module should have **one calculation and posting source of truth**.

The recommended architecture is:

```text
Purchase UI
     ↓
Purchase Calculation Service
     ↓
Purchase Validation Service
     ↓
Purchase Repository
     ↓
Atomic Database Transaction
     ├── Purchase
     ├── Purchase Items
     ├── Inventory
     ├── Warehouse
     ├── WAC
     ├── Supplier History
     ├── Supplier Payable
     ├── Account Movement
     ├── Ledger
     └── Audit
```

The UI should never independently calculate a different grand total, GST, payable, or WAC from the repository.

---

# 32. Final Professional Rule

The purchase transaction must always satisfy:

```text
Gross Purchase
− Applicable Discounts
= Net Taxable Purchase

Net Taxable Purchase
+ GST
= Grand Total

Grand Total
− Amount Paid
= Supplier Balance Due

Inventory Debit
+ GST Debit
=
Payment Credit
+ Supplier Payable Credit
```

And:

```text
TOTAL DEBIT = TOTAL CREDIT
```

This is the fundamental integrity rule for the Purchase Management System.
