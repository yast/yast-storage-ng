require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::LvmLv do
  before { devicegraph_stub("one-empty-disk.yml") }

  let(:lvm_lv) { double("LvmLv", name: "Baggins", lv_name: "Bilbo") }

  subject { described_class.new(lvm_lv) }

  include_examples "CWM::Page"
end
