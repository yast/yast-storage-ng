require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_role"

describe Y2Partitioner::Dialogs::PartitionRole do
  let(:options) { double("Format Options", name: "/dev/test_part") }

  before do
    allow(Y2Partitioner::Dialogs::PartitionRole::RoleChoice)
      .to receive(:new).and_return(term(:Empty))
  end

  subject { described_class.new("mydisk", options) }

  include_examples "CWM::Dialog"
end
