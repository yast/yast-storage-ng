require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/used_devices_tab"

describe Y2Partitioner::Widgets::UsedDevicesTab do
  subject { described_class.new(disk, pager) }

  let(:disk) { double("Disk") }

  let(:pager) { double("Pager") }

  include_examples "CWM::Tab"
end
