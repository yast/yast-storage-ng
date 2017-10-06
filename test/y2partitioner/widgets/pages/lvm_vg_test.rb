require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::LvmVg do
  before { devicegraph_stub("one-empty-disk.yml") }

  let(:pager) { double("Pager") }
  let(:lvm_vg) { double("LvmVg", vg_name: "Hugo") }

  subject { described_class.new(lvm_vg, pager) }

  include_examples "CWM::Page"
end
