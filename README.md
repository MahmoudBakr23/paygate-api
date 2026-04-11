# Paygate API

A production-grade payment gateway API built as a portfolio project targeting [Moyassar](https://moyasar.com) — Saudi Arabia's leading SAMA-licensed payment gateway. Demonstrates building a gateway from scratch: orchestration layer over Stripe (Visa/MC/Apple Pay) and Checkout.com (Mada), not just integrating one.

**Live:** https://paygate-api.fly.dev  
**OpenAPI spec:** https://paygate-api.fly.dev/api-docs  
**Dashboard:** https://paygate-dashboard.vercel.app  
**Docs:** https://paygate-docs.vercel.app

---

## Architecture

```
POST /v1/charges
       │
       ▼
AuthenticateRequest     ← API key (sk_test_xxx) or JWT
       │
       ▼
IdempotencyService      ← Redis 24h lock per Idempotency-Key header
       │
       ▼
PaymentRouterService    ← Strategy pattern: routes by payment_method + environment
       │
       ├── StripeAdapter     → Visa / Mastercard / Apple Pay
       └── CheckoutAdapter   → Mada
       │
       ▼
ChargeService           ← State machine, ledger, audit log, webhook dispatch
       │
       ▼
WebhookDispatcherService → Sidekiq → WebhookDeliveryJob (HMAC-signed, exponential retry)
```

**Key design rules:**
- Business logic lives in `app/services/` — controllers call one service and render
- Financial data is never cached — always read live from the database
- Every financial state change writes a double-entry `LedgerEntry`
- Every merchant action writes an immutable `AuditLog`
- No PAN, CVV, or raw card data ever touches this server — client-side tokenization only

### Charge state machine

```
PENDING → AUTHORIZED → CAPTURED → REFUNDED
        ↘ FAILED      ↘ VOIDED
```

### API key format

```
pk_test_{32-char-random}   # public key, sandbox
sk_test_{32-char-random}   # secret key, sandbox (bcrypt digest stored, plaintext shown once)
pk_live_{32-char-random}   # public key, live (architecture-complete; 403 in portfolio)
sk_live_{32-char-random}   # secret key, live
```

### Webhook delivery

Outbound webhooks are signed with HMAC-SHA256 (`X-PayGate-Signature` header). Retry schedule: 1m → 5m → 30m → 2h → 24h (5 attempts max).

---

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Rails 8.1 (API mode) |
| Database | PostgreSQL (`charges` table range-partitioned by `created_at`) |
| Cache / queues | Redis + Sidekiq 8.1 |
| Auth | bcrypt API keys + JWT sessions + Rack::Attack rate limiting |
| Payment adapters | Stripe 13, Checkout.com REST (no SDK) |
| Serialization | Blueprinter |
| Logging | Lograge (structured JSON, no PAN) |
| API spec | rswag (OpenAPI 3.0.1, 260 examples) |
| Deployment | Fly.io (web + worker machines, auto-stop on free tier) |

---

## Local Setup

**Requirements:** Ruby 3.3+, PostgreSQL 15+, Redis 7+

```bash
git clone https://github.com/MahmoudBakr23/paygate-api
cd paygate-api

bundle install

cp .env.example .env.test   # fill in test credentials
```

Create `.env` (not committed):

```
DATABASE_URL=postgresql://localhost/paygate_development
REDIS_URL=redis://localhost:6379/0
SECRET_KEY_BASE=<rails credentials or openssl rand -hex 64>
RAILS_MASTER_KEY=<from config/master.key>
STRIPE_SANDBOX_SECRET_KEY=sk_test_...
STRIPE_SANDBOX_WEBHOOK_SECRET=whsec_...
CHECKOUT_SANDBOX_SECRET_KEY=sk_...
CHECKOUT_SANDBOX_WEBHOOK_SECRET=...
```

```bash
bin/rails db:create db:migrate

# Start API
bin/rails s

# Start Sidekiq (separate terminal)
bundle exec sidekiq
```

---

## Running Tests

```bash
bundle exec rspec
```

260 examples, covering:
- Service objects (ChargeService, RefundService, VoidService, WebhookDispatcherService, etc.)
- Request specs for all endpoints (including idempotency, state machine transitions)
- rswag OpenAPI spec validation

CI also runs Brakeman (security audit), bundler-audit, and RuboCop.

---

## API Endpoints

Full interactive spec at https://paygate-api.fly.dev/api-docs.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/v1/auth/register` | — | Register merchant, returns JWT + sandbox key pair |
| POST | `/v1/auth/login` | — | Login, returns JWT |
| DELETE | `/v1/auth/logout` | JWT | Revoke session |
| GET | `/v1/me` | any | Merchant profile |
| PATCH | `/v1/me` | JWT | Update profile |
| GET | `/v1/me/api_keys` | any | List active API keys |
| POST | `/v1/me/api_keys` | any | Generate key pair (secret shown once) |
| DELETE | `/v1/me/api_keys/:id` | any | Revoke a key |
| GET | `/v1/me/webhook_endpoints` | any | List webhook endpoints |
| POST | `/v1/me/webhook_endpoints` | any | Register endpoint (secret shown once) |
| PATCH | `/v1/me/webhook_endpoints/:id` | any | Update endpoint |
| DELETE | `/v1/me/webhook_endpoints/:id` | any | Remove endpoint |
| GET | `/v1/me/entity_ids` | any | List entity IDs by brand |
| POST | `/v1/me/entity_ids` | any | Register entity ID |
| DELETE | `/v1/me/entity_ids/:id` | any | Remove entity ID |
| GET | `/v1/me/dashboard` | any | Aggregated stats (volume, success rate, by method) |
| POST | `/v1/charges` | sk_test | Create charge (requires `Idempotency-Key` header) |
| GET | `/v1/charges` | any | List charges (filterable by status, method, date) |
| GET | `/v1/charges/:id` | any | Get charge |
| POST | `/v1/charges/:id/void` | sk_test | Void an authorized charge |
| POST | `/v1/charges/:id/refunds` | sk_test | Refund a charge (full or partial) |
| GET | `/v1/charges/:id/refunds` | any | List refunds for a charge |
| GET | `/v1/refunds/:id` | any | Get refund |
| POST | `/v1/webhooks/verify` | any | Verify an inbound webhook signature |
| POST | `/webhooks/stripe` | — | Stripe inbound webhook (HMAC verified) |
| POST | `/webhooks/checkout` | — | Checkout.com inbound webhook (HMAC verified) |
| GET | `/health` | — | Liveness check |
| GET | `/v1/health/ready` | — | Readiness check (DB + Redis + Sidekiq) |

Authentication: `Authorization: Bearer sk_test_xxx` for API key auth; `Authorization: Bearer <jwt>` for session auth.

---

## Deployment (Fly.io)

```bash
fly deploy              # deploy latest
fly logs                # tail logs
fly status              # machine status
fly ssh console         # rails console on the live machine
```

CI deploys automatically on push to `dev` via `.github/workflows/deploy.yml`.

Backing services:
- **PostgreSQL** — Fly Postgres (attached via `fly postgres attach`)
- **Redis** — Upstash for Fly (`fly redis create`)
- **Sidekiq** — separate `worker` machine group in `fly.toml`
