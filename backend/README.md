# BizNext API

Spring Boot 3.3.4 / Java 17 customer API.

## Neon PostgreSQL

The default Spring profile connects to Neon PostgreSQL using `PGHOST`, `PGDATABASE`, `PGUSER`, and `PGPASSWORD`. Configure these as environment variables in the deployment environment; use the Neon pooled hostname for `PGHOST` when appropriate. SSL and channel binding default to `require` and can be set with `PGSSLMODE` and `PGCHANNELBINDING`. HikariCP pool settings can be adjusted with `NEON_POOL_SIZE` and `NEON_MIN_IDLE`.

Cloudinary media uploads are implemented in the Flutter app for product images and offer posters. Create an **unsigned upload preset** in Cloudinary and restrict it to images, a BizNext folder, a conservative maximum file size, and no overwrite. Configure the Flutter build with `--dart-define=CLOUDINARY_CLOUD_NAME=<cloud-name>` and `--dart-define=CLOUDINARY_UPLOAD_PRESET=<preset-name>`. An unsigned preset is public and can be abused if unrestricted, so apply Cloudinary upload restrictions and usage limits. The Cloudinary API key/secret are not required by this upload flow and must never be embedded in the Flutter app.

Copy the Neon variable names from `.env.example` into a local secret store or shell environment and supply rotated credentials there. Do not commit credentials or a populated `.env` file. The application does not load `.env` files automatically. Any credentials shared in chat, screenshots, or source files should be rotated before use.

Newly selected product and offer images are uploaded and their Cloudinary HTTPS URLs are stored in the existing SQLite image path fields. The UI can render both Cloudinary URLs and old local paths. Existing local product images and offer posters can be migrated for the active business from **Settings → Data Backup & Recovery → Migrate Images to Cloudinary**. Back up the local database first; the migration uploads one file at a time and persists each URL immediately, so it can be safely retried after interrupted uploads. Missing local files are skipped and failed uploads are reported.

Flyway applies versioned schema migrations at startup, and Hibernate is configured with `ddl-auto=validate`. The initial migration creates the customer module's empty tables, customer-type relationship, sales/ledger references needed for deletion checks, and a business-scoped normalized-mobile unique index. It does not import local SQLite data, drop tables, or enable Hibernate schema updates against Neon.

The app checks connectivity during startup as Flyway and Hibernate validate the schema. Startup will fail rather than silently fall back if Neon credentials, connectivity, or schema validation are incorrect.

## API scope

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

Business authentication/authorization is not yet enabled: the Flutter app currently authenticates entirely against local SQLite and generates its bearer token on-device. Business-scoped queries prevent accidental cross-business record access, but request `businessId` is not proof of authorization. A trusted server-side identity/business-membership source is required before production customer APIs can safely enforce user-to-business authorization. The current client-generated token must not be treated as secure server authentication.
