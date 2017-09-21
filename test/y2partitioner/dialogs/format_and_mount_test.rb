require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/format_and_mount"

describe Y2Partitioner::Dialogs::FormatAndMount do
  let(:controller) { double("FilesystemController", blk_device: partition, filesystem: nil) }
  let(:partition) { double("Partition", name: "/dev/sda1") }

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"
end
