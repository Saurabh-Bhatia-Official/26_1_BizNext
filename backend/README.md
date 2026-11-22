# BizNext API

Spring Boot 3.3.4 / Java 17 REST API.

## Neon PostgreSQL

Set `DATABASE_URL` or `NEON_DATABASE_URL` to the Neon connection URL (`postgresql://...` or `jdbc:postgresql://...`), or configure `PGHOST`, `PGDATABASE`, `PGUSER`, and `PGPASSWORD` separately (`PGPORT` defaults to `5432`). SSL and channel binding default to `require`. HikariCP pool settings use `NEON_POOL_SIZE` and `NEON_MIN_IDLE`.

For local development, copy `.env.example` to the ignored `backend/.env`, then populate it with rotated credentials from your secret manager. Spring imports that file explicitly; `.env.example` is not loaded. When starting from the repository root, the `backend/.env` path is also supported. Start the API with `mvn spring-boot:run` from the `backend` directory. The API fails fast with a clear configuration error when credentials are missing and never falls back to local file storage. Never put active credentials in `.env.example`, source code, or logs.

Product image uploads are signed by the backend and use `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET`. Keep these values only in the backend deployment secret store. Product image request bodies use multipart form data with a JSON `product` part and an optional `image` file part. JPG/JPEG, PNG, and WEBP are accepted up to 5 MB.

Cloudinary variables are backend-only secrets. Rotate any credentials that were previously stored in tracked project files before using them.

Flyway applies versioned schema migrations at startup. `V3__products_module_schema.sql` creates the business-scoped product categories and products tables, case-insensitive business-scoped SKU uniqueness, category relationship, validation checks, and product query indexes. Existing local SQLite products/categories are not automatically copied; seed or import those records through a trusted migration before using the Neon catalog.

The inventory product form sends new product images through the signed backend upload. Offer posters still use the existing Cloudinary client flow. Existing product image paths and offer posters can be migrated for the active business from **Settings → Data Backup & Recovery → Migrate Images to Cloudinary**; this legacy migration remains local-database based.

Flyway applies versioned schema migrations at startup, and Hibernate is configured with `ddl-auto=validate`. The initial migration creates the customer module's empty tables, customer-type relationship, sales/ledger references needed for deletion checks, and a business-scoped normalized-mobile unique index. It does not import local SQLite data, drop tables, or enable Hibernate schema updates against Neon.

The app checks connectivity during startup as Flyway and Hibernate validate the schema. Startup will fail rather than silently fall back if Neon credentials, connectivity, or schema validation are incorrect.

## Product API

All product routes require `businessId` for business-scoped queries.

| Method | Route | Notes |
|---|---|---|
| POST | `/api/products` | Multipart JSON `product`, optional `image`; returns 201 |
| GET | `/api/products?businessId=1&page=0&size=50` | Paginated list; supports `q`, `categoryId`, `brand`, `status`, `lowStock`, `sortBy`, `direction` |
| GET | `/api/products/{id}?businessId=1` | Product detail |
| PUT | `/api/products/{id}` | Multipart update; omitted image is retained; `removeImage=true` clears it |
| DELETE | `/api/products/{id}?businessId=1` | Returns 204; conflicts with inventory/return history |
| GET | `/api/products/search?businessId=1&q=rice` | Search name, SKU, or barcode |
| GET | `/api/products/category/{categoryId}?businessId=1` | Category filter |
| GET | `/api/products/low-stock?businessId=1` | Products at/below minimum stock |
| PATCH | `/api/products/{id}/status?businessId=1` | Body `{"status":"Active"}` or `{"status":"Inactive"}` |
| GET/POST/PUT/DELETE | `/api/products/categories` | Product category operations used by the inventory form |
| PATCH | `/api/products/{id}/stock` | Transactional stock adjustment with movement ledger entry |

`sortBy` accepts `name`, `price`, or `date`; `direction` accepts `asc` or `desc`; page sizes are capped at 200. SKU uniqueness is enforced per business in PostgreSQL. Replacing an image uploads the new file before the database update, removes it if the database write fails, and deletes the old Cloudinary image only after the update commits.

The Flutter inventory list and product create/update/delete/status/category operations use these APIs. Existing sales and purchase transactions, tiered price lists, supplier references, and the old local database's historical product data have not been migrated to Neon.

## Customer API scope

Customer routes are rooted at `/api/customers`:

| Method | Route | Notes |
|---|---|---|
| GET | `/api/customers?businessId=1&page=0&size=50` | Paginated list; size is capped at 200 |
| GET | `/api/customers/{id}?businessId=1` | Business-scoped detail |
| GET | `/api/customers/search?businessId=1&q=alice&page=0&size=50` | Name or normalized-phone search |
| GET | `/api/customers/filter?businessId=1&name=alice&phone=555&page=0&size=50` | Optional name, phone, email, and customer type filters |
| POST | `/api/customers` | Create customer; returns 201 |
| PUT | `/api/customers/{id}` | Update within the request business; cannot move a customer across businesses |
| DELETE | `/api/customers/{id}?businessId=1` | Returns 204; conflicts with sales or customer ledger history |

Create/update JSON example:

```json
{
	"businessId": 1,
	"name": "Alice Johnson",
	"phone": "+1 (555) 123-4567",
	"email": "alice@example.com",
	"address": "Main Street",
	"gstNumber": null,
	"customerTypeId": null,
	"balance": 0,
	"loyaltyPoints": 0
}
```

Paginated responses include `content`, `page`, `size`, `totalElements`, `totalPages`, and `last`. Validation returns 400, missing/out-of-scope customers return 404, duplicate normalized phones and prohibited deletes return 409, and unexpected errors return a generic 500 response.

The Flutter customer HTTP client consumes these routes and fetches list pages. It retains SQLite fallback for connection failures, while HTTP errors such as duplicate/validation responses are surfaced to the UI instead of being silently treated as a successful local save. Configure `BIZNEXT_API_BASE_URL` for the target device/platform; `localhost` refers to the device itself on mobile emulators.

Business authentication/authorization is not yet enabled: the Flutter app currently authenticates entirely against local SQLite and generates its bearer token on-device. Product and customer business-scoped queries prevent accidental cross-business data mixing but `businessId` is not proof of authorization. A trusted server-side identity/business-membership source is required before these APIs can safely enforce user-to-business authorization. Do not expose the API publicly until server-verifiable authentication and role checks are added.
