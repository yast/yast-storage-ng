require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/encrypt_password"

describe Y2Partitioner::Dialogs::EncryptPassword do
  let(:controller) { double("FilesystemController", blk_device_name: "/dev/sda1") }

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"
end
