require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/lvm_vg_page"

describe Y2Partitioner::Widgets::LvmVgPage do
  let(:pager) { double("Pager") }
  let(:lvm_vg) { double("LvmVg", vg_name: "Hugo") }

  subject { described_class.new(lvm_vg, pager) }

  include_examples "CWM::Page"
end
