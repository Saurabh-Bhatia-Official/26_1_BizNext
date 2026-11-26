# BizNext Features

BizNext is a robust, auditable, and resilient inventory and purchasing system that maintains accurate stock and pricing consistency from the moment products are procured from suppliers until they are sold through the Point of Sale (POS) terminal.

## Core Features

### 1. Inventory Management
- **Stock Discrepancy Prevention**: Every stock movement is logged as an immutable ledger entry. Manual stock overrides are restricted to ensure accuracy.
- **Accurate Inventory Valuation**: Real-time inventory valuation based on Weighted Average Cost (WAC) and FIFO principles.
- **Stock Tracking & Alerts**: Track stock levels dynamically. Receive low stock and out-of-stock alerts based on predefined minimum thresholds.
- **Stock Adjustments & Returns**: Dedicated workflows for managing damages, wastages, physical discrepancies, purchase returns, and sales returns.

### 2. Supplier & Purchase Management
- **Supplier Relationship Memory**: Comprehensive supplier tracking including purchase history, last purchase rate, outstanding balances, and supplier-specific SKUs.
- **Purchase Order & Entry**: Streamlined workflow for logging purchases, instantly updating the stock ledger and recalculating Weighted Average Costs.

### 3. POS Billing & Dynamic Pricing
- **Pricing Integrity & Tiered Pricing**: Automated resolution of selling prices based on customer type (e.g., Retail, Wholesale, Dealer, Distributor) and volume/quantity purchased.
- **Minimum Price Protection**: Enforcement of a strict price floor. Sales below the minimum selling price require explicit authenticated manager approval.
- **Seamless POS Checkout**: Quick product lookups via barcode or search, instant price evaluation, and real-time stock deduction upon billing.

### 4. Product Catalog
- **Structured Master Data**: Products are organized using Categories, Subcategories, Brands, and precise tax codes (HSN/SAC & GST%).
- **Advanced Product Profiling**: Each product maintains data for cost price (WAC), maximum retail price (MRP), base selling price, minimum selling price, reorder limits, and multiple barcodes.

### 5. Auditing & Reporting
- **Immutable Audit Trails**: Actions such as price overrides, manual discounts, and stock adjustments are strictly recorded with timestamps, user IDs, and previous/new state details.
- **Comprehensive Analytics**: Access to various operational reports including:
  - Stock Movement Ledger
  - Sales Reports by Category / Subcategory
  - Price-list & Customer-type Performance
  - Supplier Performance & Outstanding Balance
  - Stock Valuation & Risk Alerts

### 6. Role-Based Access Control (RBAC)
- Multi-tier access management providing distinct permissions for:
  - **Owner / Admin & Manager**: Full system access, including overrides and price changes.
  - **Purchase Manager**: Specialized access to purchases and supplier management.
  - **Inventory Manager**: Dedicated role for stock management and adjustments.
  - **Cashier**: Restricted POS access focused on billing, with approvals needed for critical overrides.
