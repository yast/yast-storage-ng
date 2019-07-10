require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/fstab_options"

describe Y2Partitioner::Dialogs::FstabOptions do
  let(:options) { double("Format Options") }

  subject { described_class.new(options) }

  include_examples "CWM::Dialog"
end
