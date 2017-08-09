require_relative "../test_helper"

require "y2partitioner/format_mount/base"

describe Y2Partitioner::FormatMount::Base do
  let(:subject) { described_class.new(partition, options) }
  let(:options) { Y2Partitioner::FormatMount::Options.new }
  let(:filesystem) { instance_double(Y2Storage::Filesystems::Type) }
  let(:partition) do
    instance_double(
      Y2Storage::Partition,
      name:       "/dev/test_partition",
      basename:   "test_partition",
      id:         Y2Storage::PartitionId::LVM,
      type:       "primary",
      filesystem: filesystem
    )
  end

  context "#apply_options!" do
    before do
      allow(partition).to receive(:id=)
      allow(subject).to receive(:apply_format_options!)
      allow(subject).to receive(:apply_mount_options!)
    end

    it "sets the partition id" do
      expect(partition).to receive(:id=)

      subject.apply_options!
    end

    it "applies format options over the partition" do
      expect(subject).to receive(:apply_format_options!)
      subject.apply_options!
    end

    it "applies mount options over the partition" do
      expect(subject).to receive(:apply_mount_options!)

      subject.apply_options!
    end

  end

  context "#apply_format_options!" do
    let(:encrypted) { instance_double(Y2Storage::Encryption) }

    before do
      allow(partition).to receive(:remove_descendants)
      allow(partition).to receive(:create_filesystem).and_return(created_filesystem)
      allow(partition).to receive(:create_encryption)
      allow(created_filesystem).to receive(:supports_btrfs_subvolumes?).and_return(btrfs)
    end

    let(:created_filesystem) { instance_double(Y2Storage::Filesystems::BlkFilesystem) }

    let(:btrfs) { false }

    context "when the partition has not been set to be formated or encrypted" do
      it "returns false" do
        expect(subject.apply_format_options!).to eql(false)
      end
    end

    context "when the partition has been set to be formated or encrypted" do
      before do
        allow(options).to receive(:format).and_return(true)
      end

      it "removes all partition descendants" do
        expect(partition).to receive(:remove_descendants)

        subject.apply_format_options!
      end

      it "encrypts the partition if encrypted has been selected" do
        allow(options).to receive(:format).and_return(false)
        allow(options).to receive(:encrypt).and_return(true)
        allow(options).to receive(:password).and_return("LOTP_password")
        expect(partition).to receive(:create_encryption).with("cr_#{partition.basename}")
          .and_return(encrypted)
        expect(encrypted).to receive(:password=).with("LOTP_password")

        subject.apply_format_options!
      end

      it "creates a new filesystem with the filesystem type configured if formated" do
        allow(options).to receive(:filesystem_type).and_return(filesystem)
        expect(partition).to receive(:create_filesystem).with(filesystem)

        subject.apply_format_options!
      end

      context "and the filesystem is btrfs" do
        let(:created_filesystem) { instance_double(Y2Storage::Filesystems::Btrfs) }
        let(:btrfs) { true }

        it "ensures a default btrfs subvolume" do
          expect(created_filesystem).to receive(:ensure_default_btrfs_subvolume)
          subject.apply_format_options!
        end
      end

      it "returns true" do
        expect(subject.apply_format_options!).to eql(true)
      end
    end
  end

  context "#apply_mount_options!" do
    it "returns false if partition does not have" do
    end
    it "empties partition filesystem mountpoint in case of no mount option" do
    end
  end
end
