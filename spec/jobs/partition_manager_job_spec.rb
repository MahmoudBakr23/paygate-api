require "rails_helper"

RSpec.describe PartitionManagerJob do
  describe "#perform" do
    let(:next_month)  { Date.current.next_month.beginning_of_month }
    let(:month_after) { next_month.next_month }
    let(:partition_name) { "charges_#{next_month.strftime('%Y_%m')}" }

    after do
      ActiveRecord::Base.connection.execute(
        "DROP TABLE IF EXISTS #{partition_name}"
      )
    end

    it "creates the next month's partition" do
      described_class.new.perform

      result = ActiveRecord::Base.connection.execute(
        "SELECT relname FROM pg_class WHERE relname = '#{partition_name}' AND relkind = 'r'"
      )
      expect(result.any?).to be(true)
    end

    it "is idempotent — does not raise when partition already exists" do
      described_class.new.perform

      expect { described_class.new.perform }.not_to raise_error
    end
  end
end
