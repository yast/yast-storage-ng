require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_role"

describe Y2Partitioner::Dialogs::PartitionRole do
  let(:controller) { double("FilesystemController", blk_device: partition, wizard_title: "") }
  let(:partition) { double("Partition", partitionable: disk) }
  let(:disk) { double("Disk", name: "/dev/sda") }

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::PartitionRole::RoleChoice do
    subject { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"
  end
end
