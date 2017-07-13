require_relative "../test_helper"

require "y2partitioner/format_mount/options"

describe Y2Partitioner::FormatMount::Options do

  context "#initialize" do
    it "sets the defauts options" do
      expect_any_instance_of(described_class).to receive(:set_defaults!)

      subject
    end

    context "when a specific role is given" do
      it "also set options for the specific role" do
        expect_any_instance_of(described_class)
          .to receive(:set_defaults!)
        expect_any_instance_of(described_class)
          .to receive(:options_for_role).with(:swap)

        described_class.new(role: :swap)
      end
    end

    context "when a specific partition is given" do
      let(:partition) { instance_double(Y2Storage::Partition, name: "/dev/test_partition") }

      it "also set options for the specific partition" do
        expect_any_instance_of(described_class)
          .to receive(:set_defaults!)
        expect_any_instance_of(described_class)
          .to receive(:options_for_partition).with(partition)

        described_class.new(partition: partition)
      end
    end
  end

  context "#options_for_role" do
    let(:options) { described_class.new }

    context "when the given role is :swap" do
      before do
        options.options_for_role(:swap)
      end

      it "sets the partition_id as Y2Storage::PartitionId::SWAP" do
        expect(options.partition_id).to eql(Y2Storage::PartitionId::SWAP)
      end

      it "sets the filesystem as swap" do
        expect(options.filesystem_type).to eql(Y2Storage::Filesystems::Type::SWAP)
      end

      it "sets the mount_point as swap" do
        expect(options.mount_point).to eql("swap")
      end
    end

    context "when the given role is :efi_boot" do
      before do
        options.options_for_role(:efi_boot)
      end

      it "sets the partition_id as Y2Storage::PartitionId::ESP" do
        expect(options.partition_id).to eql(Y2Storage::PartitionId::ESP)
      end

      it "sets the filesystem as VFAT" do
        expect(options.filesystem_type).to eql(Y2Storage::Filesystems::Type::VFAT)
      end

      it "sets the mount_point as /boot/efi" do
        expect(options.mount_point).to eql("/boot/efi")
      end
    end

    context "when the given role is :system" do
      before do
        options.options_for_role(:system)
      end
      it "sets the partition_id as Y2Storage::PartitionId::LINUX" do
        expect(options.partition_id).to eql(Y2Storage::PartitionId::LINUX)
      end

      it "sets the filesystem with the default" do
        expect(options.filesystem_type).to eql(described_class::DEFAULT_FS)
      end
    end
  end

  context "#options_for_partition" do
    let(:options) { described_class.new }
    let(:filesystem) { instance_double(Y2Storage::Filesystems::Type) }
    let(:partition) do
      instance_double(
        Y2Storage::Partition,
        name:       "/dev/test_partition",
        id:         Y2Storage::PartitionId::LVM,
        type:       "primary",
        filesystem: filesystem
      )
    end

    before do
      allow(options).to receive(:options_for_filesystem)
    end

    context "given a partition" do
      it "sets the name, type and partition_id options from the partition" do
        options.options_for_partition(partition)

        expect(options.name).to eql("/dev/test_partition")
        expect(options.partition_id).to eql(Y2Storage::PartitionId::LVM)
        expect(options.partition_type).to eql("primary")
      end

      it "sets the rest of options based on its filesystem" do
        expect(options).to receive(:options_for_filesystem).with(filesystem)

        options.options_for_partition(partition)
      end
    end
  end
end
