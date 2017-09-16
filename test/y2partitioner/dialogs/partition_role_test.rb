require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_role"

describe Y2Partitioner::Dialogs::PartitionRole do
  let(:controller) { double("FilesystemController", blk_device: partition) }
  let(:partition) { double("Partition", partitionable: disk) }
  let(:disk) { double("Disk", name: "/dev/sda") }

  before do
    allow(Y2Partitioner::Dialogs::PartitionRole::RoleChoice)
      .to receive(:new).and_return(term(:Empty))
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"
end
