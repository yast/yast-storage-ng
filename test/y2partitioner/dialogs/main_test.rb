require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/main"

describe Y2Partitioner::Dialogs::Main do
  before { devicegraph_stub("one-empty-disk.yml") }

  subject { described_class.new }

  include_examples "CWM::Dialog"
end
