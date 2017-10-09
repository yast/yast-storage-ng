require_relative "../test_helper"

require "yast"
require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/md_options"
require "y2partitioner/sequences/controllers"

Yast.import "UI"

describe Y2Partitioner::Dialogs::MdOptions do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:controller) do
    Y2Partitioner::Sequences::Controllers::Md.new
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::MdOptions::ChunkSize do
    include_examples "CWM::ComboBox"
  end

  describe Y2Partitioner::Dialogs::MdOptions::Parity do
    include_examples "CWM::ComboBox"
  end
end
