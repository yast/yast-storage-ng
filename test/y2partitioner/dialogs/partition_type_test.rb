require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_type"

describe Y2Partitioner::Dialogs::PartitionType do
  let(:controller) { double("PartitionController", unused_slots: slots, disk_name: "/dev/sda") }
  let(:slots) { [] }

  subject { described_class.new(controller) }
  before do
    allow(Y2Partitioner::Dialogs::PartitionType::TypeChoice)
      .to receive(:new).and_return(term(:Empty))
  end
  include_examples "CWM::Dialog"
end

describe Y2Partitioner::Dialogs::PartitionType::TypeChoice do
  let(:controller) { double("PartitionController", unused_slots: slots, disk_name: "/dev/sda") }
  let(:slots) { [double("Slot", :"possible?" => true)] }

  subject { described_class.new(controller) }

  include_examples "CWM::RadioButtons"
end
