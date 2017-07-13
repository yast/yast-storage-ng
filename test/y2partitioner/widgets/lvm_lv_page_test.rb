require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/lvm_lv_page"

describe Y2Partitioner::Widgets::LvmLvPage do
  let(:lvm_lv) { double("LvmLv", name: "Baggins", lv_name: "Bilbo") }

  subject { described_class.new(lvm_lv) }

  include_examples "CWM::Page"
end
