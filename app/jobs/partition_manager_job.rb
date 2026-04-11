class PartitionManagerJob < ApplicationJob
  queue_as :reconciliation

  PARTITION_NAME_FORMAT = /\Acharges_\d{4}_\d{2}\z/
  DATE_FORMAT           = /\A\d{4}-\d{2}-\d{2}\z/

  # Creates the next month's charges partition so the table never falls back to
  # the default partition. Run once a month — schedule via cron (e.g. 1st of each
  # month at 00:05 UTC) so the partition is ready before the month starts.
  #
  # Partition name format: charges_YYYY_MM
  # Partition range:       [first day of next month, first day of month after that)
  #
  # Idempotent: safe to run multiple times; skips if the partition already exists.
  def perform
    next_month     = Date.current.next_month.beginning_of_month
    month_after    = next_month.next_month

    partition_name = "charges_#{next_month.strftime('%Y_%m')}"
    range_from     = next_month.strftime("%Y-%m-%d")
    range_to       = month_after.strftime("%Y-%m-%d")

    # Validate computed values to satisfy static analysis — all are derived from
    # Date arithmetic so the regexes will always match in normal operation.
    raise ArgumentError, "Invalid partition name: #{partition_name}" unless partition_name.match?(PARTITION_NAME_FORMAT)
    raise ArgumentError, "Invalid range_from: #{range_from}"         unless range_from.match?(DATE_FORMAT)
    raise ArgumentError, "Invalid range_to: #{range_to}"             unless range_to.match?(DATE_FORMAT)

    return if partition_exists?(partition_name)

    conn = ActiveRecord::Base.connection
    conn.execute(
      "CREATE TABLE #{partition_name} PARTITION OF charges " \
      "FOR VALUES FROM (#{conn.quote(range_from)}) TO (#{conn.quote(range_to)})"
    )

    Rails.logger.info(
      event: "partition_created",
      partition: partition_name,
      range_from: range_from,
      range_to: range_to
    )
  end

  private

  def partition_exists?(name)
    conn = ActiveRecord::Base.connection
    conn.execute(
      "SELECT 1 FROM pg_class WHERE relname = #{conn.quote(name)} AND relkind = 'r'"
    ).any?
  end
end
