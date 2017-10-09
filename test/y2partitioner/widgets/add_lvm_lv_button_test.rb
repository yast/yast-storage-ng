require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/add_lvm_lv_button"

describe Y2Partitioner::Widgets::AddLvmLvButton do
  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }
  let(:sequence) { double("AddLvmLv", run: :result) }

  before do
    devicegraph_stub("lvm-two-vgs.yml")
    allow(Y2Partitioner::Sequences::AddLvmLv).to receive(:new).and_return sequence
  end

  subject(:button) { described_class.new(vg) }

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "opens the workflow for the correct VG" do
      expect(Y2Partitioner::Sequences::AddLvmLv).to receive(:new).with(vg)
      button.handle
    end

    it "returns :redraw independently of the workflow result" do
      expect(button.handle).to eq :redraw
    end
  end
end
