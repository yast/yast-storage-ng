require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_type"

describe Y2Partitioner::Dialogs::PartitionType do
  let(:ptemplate) { double("partition template") }
  let(:slots) { [] }

  subject { described_class.new("mydisk", ptemplate, slots) }
  before do
    allow(Y2Partitioner::Dialogs::PartitionType::TypeChoice)
      .to receive(:new).and_return(term(:Empty))
  end
  include_examples "CWM::Dialog"
end

describe Y2Partitioner::Dialogs::PartitionType::TypeChoice do
  let(:ptemplate) { double("partition template") }
  let(:slots) { [double("Slot", :"possible?" => true)] }

  subject { described_class.new(ptemplate, slots) }

  include_examples "CWM::RadioButtons"
end
