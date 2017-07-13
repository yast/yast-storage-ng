require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/format_and_mount"

describe Y2Partitioner::Dialogs::FormatAndMount do
  let(:options) { double("Format Options", name: "/dev/test_part") }

  subject { described_class.new(options) }

  include_examples "CWM::Dialog"
end
