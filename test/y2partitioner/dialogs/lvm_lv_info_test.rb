require_relative "../test_helper"

require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs"
require "y2partitioner/sequences/controllers"

describe Y2Partitioner::Dialogs::LvmLvInfo do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

  let(:controller) do
    Y2Partitioner::Sequences::Controllers::LvmLv.new(vg)
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::LvmLvInfo::NameWidget do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#validate" do
      pending
    end

    describe "#store" do
      it "sets #lv_name in the controller" do
        expect(controller).to receive(:lv_name=)
        widget.store
      end
    end
  end
end
