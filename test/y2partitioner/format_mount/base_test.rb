require_relative "../test_helper"

require "y2partitioner/format_mount/base"

describe Y2Partitioner::FormatMount::Base do
  let(:subject) { described_class.new(partition, options) }
  let(:options) { Y2Partitioner::FormatMount::Options.new }
  let(:filesystem_type) { instance_double(Y2Storage::Filesystems::Type) }
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
  let(:filesystem) { instance_double(Y2Storage::Filesystems::BlkFilesystem) }

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
        allow(options).to receive(:filesystem_type).and_return(filesystem_type)
        expect(partition).to receive(:create_filesystem).with(filesystem_type)

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
    before do
      fake_scenario("mixed_disks_btrfs")
    end

    let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

    let(:dev_name) { "/dev/sda2" }

    let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    context "when the partiton has not filesystem" do
      let(:filesystem) { nil }

      it "returns false" do
        expect(subject.apply_mount_options!).to be(false)
      end
    end

    context "when the partition has a filesystem" do
      let(:filesystem) { blk_device.filesystem }

      before do
        allow(options).to receive(:mount).and_return(mount)
        allow(options).to receive(:mount_point).and_return(mount_point)
        allow(filesystem).to receive(:supports_btrfs_subvolumes?).and_return(btrfs)
      end

      let(:mount) { false }
      let(:mount_point) { nil }
      let(:btrfs) { false }

      it "returns true" do
        expect(subject.apply_mount_options!).to be(true)
      end

      context "and the filesystem is not mounted" do
        let(:mount) { false }

        context "and the filesystem was not mounted" do
          before do
            allow(filesystem).to receive(:mount_point).and_return(nil)
          end

          it "does not set the mount point" do
            expect(filesystem).to_not receive(:mount_point=)
            subject.apply_mount_options!
          end
        end

        context "and the filesystem was mounted" do
          it "unmounts the filesystem" do
            subject.apply_mount_options!
            expect(filesystem.mount_point).to be_empty
          end
        end
      end

      context "and the filesystem is mounted" do
        let(:mount) { true }

        context "and the mount point has not changed" do
          let(:dev_name) { "/dev/sdb5" }
          let(:mount_point) { filesystem.mount_point }

          it "does not set the mount point" do
            expect(filesystem).to_not receive(:mount_point=)
            subject.apply_mount_options!
          end
        end

        context "and the mount point has changed" do
          let(:dev_name) { "/dev/sdb2" } # mounted at /mnt
          let(:mount_point) { "/" }

          it "sets the new mount point" do
            subject.apply_mount_options!
            expect(filesystem.mount_point).to eq(mount_point)
          end

          context "and the filesystem is Btrfs" do
            let(:btrfs) { true }

            it "deletes the not probed subvolumes" do
              path = "@/foo"
              filesystem.create_btrfs_subvolume(path, false)
              subject.apply_mount_options!

              expect(filesystem.find_btrfs_subvolume_by_path(path)).to be_nil
            end

            it "does not delete the probed subvolumes" do
              subvolumes = filesystem.btrfs_subvolumes
              subject.apply_mount_options!

              expect(filesystem.btrfs_subvolumes).to include(*subvolumes)
            end

            it "updates the subvolumes mount points" do
              subject.apply_mount_options!
              mount_points = filesystem.btrfs_subvolumes.map(&:mount_point)
              expect(mount_points).to all(start_with(mount_point))
            end

            it "refresh btrfs subvolumes for root" do
              expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_root_subvolumes_shadowing)
              subject.apply_mount_options!
            end

            context "and the new mount point is root" do
              let(:mount_point) { "/" }

              it "adds the proposed subvolumes that have not been probed" do
                specs = Y2Storage::SubvolSpecification.for_current_product

                paths = specs.map { |s| filesystem.btrfs_subvolume_path(s.path) }
                expect(paths.any? { |p| filesystem.find_btrfs_subvolume_by_path(p).nil? }).to be(true)

                subject.apply_mount_options!

                paths = specs.map { |s| filesystem.btrfs_subvolume_path(s.path) }
                expect(paths.any? { |p| filesystem.find_btrfs_subvolume_by_path(p).nil? }).to be(false)
              end
            end

            context "and the new mount point is not root" do
              let(:mount_point) { "/bar" }

              it "does not add new subvolumes" do
                paths = filesystem.btrfs_subvolumes.map(&:path)
                subject.apply_mount_options!

                expect(filesystem.btrfs_subvolumes.map(&:path)).to eq(paths)
              end
            end
          end
        end
      end
    end
  end
end
