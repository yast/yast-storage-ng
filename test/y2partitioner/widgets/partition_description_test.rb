require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/partition_description"

describe Y2Partitioner::Widgets::PartitionDescription do
  let(:partition) do
    double("Partition",
      name: "/dev/hdz1",
      size: Y2Storage::DiskSize.new(5),
      udev_paths: ["p", "pp"],
      udev_ids: ["i", "ii"],
      filesystem_type: Y2Storage::Filesystems::Type::XFS,
      filesystem_mountpoint: "/mnt",
      filesystem_label: "ACME", :"encrypted?" => false)
  end

  subject { described_class.new(partition) }

  include_examples "CWM::RichText"
  describe "#init" do
    it "runs without failure" do
      expect { subject.init }.to_not raise_error
    end
  end
end
