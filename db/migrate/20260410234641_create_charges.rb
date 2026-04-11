class CreateCharges < ActiveRecord::Migration[8.1]
  def up
    # Partitioned by created_at (RANGE). Composite PK (id, created_at) is required
    # by PostgreSQL when partitioning — single-column PKs are not supported on
    # range-partitioned tables. Rails queries by id (WHERE id = ?) which is
    # functionally correct; partition pruning kicks in when created_at is also
    # present in the query.
    #
    # FK from refunds.charge_id → charges(id) is enforced at the app layer rather
    # than the DB layer because PostgreSQL requires FKs to a partitioned table to
    # reference the full PK (id, created_at), which would require the FK column to
    # also carry created_at — not practical for the refunds schema.
    execute <<~SQL
      CREATE TABLE charges (
        id                 UUID        NOT NULL DEFAULT gen_random_uuid(),
        merchant_id        UUID        NOT NULL REFERENCES merchants(id),
        amount             INTEGER     NOT NULL,
        currency           VARCHAR(3)  NOT NULL DEFAULT 'SAR',
        payment_method     VARCHAR     NOT NULL,
        status             VARCHAR     NOT NULL DEFAULT 'pending',
        provider           VARCHAR     NOT NULL,
        provider_charge_id VARCHAR,
        idempotency_key    VARCHAR,
        metadata           JSONB       NOT NULL DEFAULT '{}',
        failure_code       VARCHAR,
        failure_message    VARCHAR,
        environment        VARCHAR     NOT NULL,
        captured_at        TIMESTAMP,
        created_at         TIMESTAMP(6) NOT NULL,
        updated_at         TIMESTAMP(6) NOT NULL,
        PRIMARY KEY (id, created_at)
      ) PARTITION BY RANGE (created_at);

      -- Default catch-all partition; monthly partitions would be created by a
      -- scheduled job (PartitionManagerJob) in production.
      CREATE TABLE charges_default PARTITION OF charges DEFAULT;

      CREATE INDEX index_charges_on_merchant_id     ON charges (merchant_id);
      CREATE INDEX index_charges_on_idempotency_key ON charges (idempotency_key);
      CREATE INDEX index_charges_on_status          ON charges (status);
      CREATE INDEX index_charges_on_environment     ON charges (environment);
      CREATE INDEX index_charges_on_created_at      ON charges (created_at);
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS charges CASCADE"
  end
end
