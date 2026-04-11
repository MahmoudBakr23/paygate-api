require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.to_s + "/swagger"

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Paygate API",
        version: "v1",
        description: <<~DESC
          Paygate is a payment gateway API that abstracts Stripe (Visa/MC/Apple Pay)
          and Checkout.com (Mada) behind a unified interface. All endpoints are prefixed
          with `/v1`. Financial data is always live — never cached.

          **Authentication:** Use your secret API key (`sk_test_xxx`) as a Bearer token,
          or a JWT session token returned by `/v1/auth/login`.

          **Sandbox keys** (`sk_test_xxx`) process real transactions against provider
          sandboxes. **Live keys** (`sk_live_xxx`) return 403 — live mode is architecture-
          complete but not activated in this portfolio instance.
        DESC
      },
      servers: [
        { url: "https://paygate-api.fly.dev", description: "Sandbox (Fly.io)" },
        { url: "http://localhost:3000", description: "Local development" }
      ],
      components: {
        securitySchemes: {
          BearerAuth: {
            type: :http,
            scheme: :bearer,
            description: "Secret API key (`sk_test_xxx`) or JWT session token"
          }
        },
        schemas: {
          # ── Error ────────────────────────────────────────────────────────
          Error: {
            type: :object,
            required: %w[error],
            properties: {
              error: {
                type: :object,
                required: %w[code message],
                properties: {
                  code: { type: :string, example: "unauthorized" },
                  message: { type: :string, example: "Invalid or missing API key" }
                }
              }
            }
          },

          # ── Merchant ─────────────────────────────────────────────────────
          Merchant: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              name: { type: :string, example: "Acme Corp" },
              email: { type: :string, format: :email, example: "acme@example.com" },
              environment: { type: :string, enum: %w[sandbox live], example: "sandbox" },
              enabled_payment_methods: {
                type: :array,
                items: { type: :string, enum: %w[card mada apple_pay] },
                example: %w[card mada apple_pay]
              },
              webhook_url: { type: :string, nullable: true, example: "https://merchant.example.com/hooks" },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            }
          },

          # ── API Key ───────────────────────────────────────────────────────
          ApiKey: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              environment: { type: :string, enum: %w[sandbox live] },
              public_key: { type: :string, example: "pk_test_abc123..." },
              last_used_at: { type: :string, format: "date-time", nullable: true },
              revoked_at: { type: :string, format: "date-time", nullable: true },
              created_at: { type: :string, format: "date-time" }
            }
          },

          ApiKeyCreated: {
            type: :object,
            description: "Returned once at creation — secret_key is never shown again",
            properties: {
              public_key: { type: :string, example: "pk_test_abc123..." },
              secret_key: { type: :string, example: "sk_test_xyz789..." },
              api_key: { "$ref" => "#/components/schemas/ApiKey" }
            }
          },

          # ── Charge ────────────────────────────────────────────────────────
          Charge: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              merchant_id: { type: :string, format: :uuid },
              amount: { type: :integer, description: "Smallest currency unit (halalas/cents)", example: 1000 },
              currency: { type: :string, example: "SAR" },
              payment_method: { type: :string, enum: %w[card mada apple_pay], example: "card" },
              status: {
                type: :string,
                enum: %w[pending authorized captured failed voided refunded],
                example: "captured"
              },
              provider: { type: :string, enum: %w[stripe checkout], example: "stripe" },
              provider_charge_id: { type: :string, nullable: true, example: "pi_3abc..." },
              idempotency_key: { type: :string, nullable: true, example: "550e8400-e29b-41d4-a716-446655440000" },
              metadata: { type: :object, additionalProperties: true, example: { order_id: "ORD-42" } },
              failure_code: { type: :string, nullable: true },
              failure_message: { type: :string, nullable: true },
              environment: { type: :string, enum: %w[sandbox live] },
              captured_at: { type: :string, format: "date-time", nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            }
          },

          # ── Refund ────────────────────────────────────────────────────────
          Refund: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              charge_id: { type: :string, format: :uuid },
              merchant_id: { type: :string, format: :uuid },
              amount: { type: :integer, example: 500 },
              reason: {
                type: :string,
                nullable: true,
                enum: %w[duplicate fraudulent requested_by_customer],
                example: "requested_by_customer"
              },
              status: { type: :string, enum: %w[pending succeeded failed], example: "succeeded" },
              provider_refund_id: { type: :string, nullable: true, example: "re_abc..." },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            }
          },

          # ── Webhook Endpoint ──────────────────────────────────────────────
          WebhookEndpoint: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              merchant_id: { type: :string, format: :uuid },
              url: { type: :string, format: :uri, example: "https://merchant.example.com/hooks" },
              events: {
                type: :array,
                items: { type: :string },
                example: %w[charge.captured charge.failed]
              },
              active: { type: :boolean, example: true },
              created_at: { type: :string, format: "date-time" }
            }
          },

          WebhookEndpointCreated: {
            type: :object,
            description: "Returned once at creation — webhook_secret is never shown again",
            properties: {
              webhook_endpoint: { "$ref" => "#/components/schemas/WebhookEndpoint" },
              webhook_secret: { type: :string, example: "whsec_abc123..." }
            }
          },

          # ── Entity ID ─────────────────────────────────────────────────────
          EntityId: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              merchant_id: { type: :string, format: :uuid },
              brand: { type: :string, enum: %w[card mada apple_pay], example: "card" },
              environment: { type: :string, enum: %w[sandbox live], example: "sandbox" },
              entity_id: { type: :string, example: "8ac7a4ca12345678" },
              created_at: { type: :string, format: "date-time" }
            }
          },

          # ── Dashboard Stats ───────────────────────────────────────────────
          DashboardStats: {
            type: :object,
            properties: {
              total_charges: { type: :integer, example: 42 },
              captured_count: { type: :integer, example: 35 },
              failed_count: { type: :integer, example: 5 },
              refunded_count: { type: :integer, example: 2 },
              total_volume: { type: :integer, description: "Captured volume in smallest currency unit", example: 175_000 },
              currency: { type: :string, example: "SAR" },
              success_rate: { type: :number, format: :float, example: 83.33 },
              volume_by_method: {
                type: :object,
                properties: {
                  card: { type: :integer, example: 120_000 },
                  mada: { type: :integer, example: 55_000 },
                  apple_pay: { type: :integer, example: 0 }
                }
              }
            }
          },

          # ── Request bodies ────────────────────────────────────────────────
          RegisterRequest: {
            type: :object,
            required: %w[name email password],
            properties: {
              name: { type: :string, example: "Acme Corp" },
              email: { type: :string, format: :email, example: "acme@example.com" },
              password: { type: :string, example: "Password1!" }
            }
          },

          LoginRequest: {
            type: :object,
            required: %w[email password],
            properties: {
              email: { type: :string, format: :email, example: "acme@example.com" },
              password: { type: :string, example: "Password1!" }
            }
          },

          CreateChargeRequest: {
            type: :object,
            required: %w[amount currency payment_method token],
            properties: {
              amount: { type: :integer, description: "In smallest currency unit", example: 1000 },
              currency: { type: :string, example: "SAR" },
              payment_method: { type: :string, enum: %w[card mada apple_pay], example: "card" },
              token: { type: :string, description: "Provider-issued one-time token", example: "tok_visa" },
              metadata: { type: :object, additionalProperties: true }
            }
          },

          CreateRefundRequest: {
            type: :object,
            required: %w[amount],
            properties: {
              amount: { type: :integer, description: "In smallest currency unit", example: 500 },
              reason: {
                type: :string,
                enum: %w[duplicate fraudulent requested_by_customer],
                example: "requested_by_customer"
              }
            }
          },

          UpdateMerchantRequest: {
            type: :object,
            properties: {
              name: { type: :string, example: "Acme Corp Updated" },
              webhook_url: { type: :string, format: :uri, example: "https://merchant.example.com/hooks" },
              enabled_payment_methods: {
                type: :array,
                items: { type: :string, enum: %w[card mada apple_pay] }
              }
            }
          },

          CreateApiKeyRequest: {
            type: :object,
            properties: {
              environment: { type: :string, enum: %w[sandbox live], default: "sandbox" }
            }
          },

          CreateWebhookEndpointRequest: {
            type: :object,
            required: %w[url events],
            properties: {
              url: { type: :string, format: :uri, example: "https://merchant.example.com/hooks" },
              events: {
                type: :array,
                items: {
                  type: :string,
                  enum: %w[charge.pending charge.authorized charge.captured charge.failed
                           charge.voided refund.created refund.succeeded refund.failed]
                },
                example: %w[charge.captured charge.failed]
              }
            }
          },

          UpdateWebhookEndpointRequest: {
            type: :object,
            properties: {
              url: { type: :string, format: :uri },
              events: { type: :array, items: { type: :string } },
              active: { type: :boolean }
            }
          },

          CreateEntityIdRequest: {
            type: :object,
            required: %w[brand environment entity_id],
            properties: {
              brand: { type: :string, enum: %w[card mada apple_pay], example: "card" },
              environment: { type: :string, enum: %w[sandbox live], example: "sandbox" },
              entity_id: { type: :string, example: "8ac7a4ca12345678" }
            }
          },

          VerifyWebhookRequest: {
            type: :object,
            required: %w[endpoint_id payload signature],
            properties: {
              endpoint_id: { type: :string, format: :uuid },
              payload: { type: :string, description: "Raw JSON string that was received" },
              signature: { type: :string, description: "X-PayGate-Signature header value", example: "sha256=abc123..." }
            }
          }
        }
      },
      security: [{ BearerAuth: [] }]
    }
  }

  config.openapi_format = :yaml
end
