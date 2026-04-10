class PartitionManagerJob < ApplicationJob
  queue_as :reconciliation

  # Creates the next month's charges partition so the table never falls back to
  # the default partition. Run once a month — schedule via cron (e.g. 1st of each
  # month at 00:05 UTC) so the partition is ready before the month starts.
  #
  # Partition name format: charges_YYYY_MM
  # Partition range:       [first day of next month, first day of month after that)
  #
  # Idempotent: safe to run multiple times; skips if the partition already exists.
  def perform
    next_month      = Date.current.next_month.beginning_of_month
    month_after     = next_month.next_month

    partition_name  = "charges_#{next_month.strftime('%Y_%m')}"
    range_from      = next_month.strftime("%Y-%m-%d")
    range_to        = month_after.strftime("%Y-%m-%d")

    return if partition_exists?(partition_name)

    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE #{partition_name} PARTITION OF charges
        FOR VALUES FROM ('#{range_from}') TO ('#{range_to}')
    SQL

    Rails.logger.info(
      event: "partition_created",
      partition: partition_name,
      range_from: range_from,
      range_to: range_to
    )
  end

  private

  def partition_exists?(name)
    ActiveRecord::Base.connection.execute(<<~SQL).any?
      SELECT 1 FROM pg_class WHERE relname = '#{name}' AND relkind = 'r'
    SQL
  end
end
