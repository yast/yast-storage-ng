require_relative "../test_helper"

require "y2partitioner/format_mount/base"

describe Y2Partitioner::FormatMount::Base do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")

    allow(options).to receive(:format).and_return(format)
    allow(options).to receive(:encrypt).and_return(encrypt)
    allow(options).to receive(:password).and_return(password)
    allow(options).to receive(:filesystem_type).and_return(filesystem_type)
    allow(options).to receive(:mount).and_return(mount)
    allow(options).to receive(:mount_point).and_return(mount_point)
  end

  let(:subject) { described_class.new(partition, options) }

  let(:options) { Y2Partitioner::FormatMount::Options.new }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }
  let(:dev_name) { "/dev/sda2" }
  let(:partition) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  let(:format) { false }
  let(:encrypt) { false }
  let(:password) { "LOTP_password" }
  let(:filesystem_type) { Y2Storage::Filesystems::Type::EXT4 }
  let(:mount) { false }
  let(:mount_point) { "" }

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
    context "when the partition has not been set to be formatted or encrypted" do
      let(:format) { false }
      let(:encrypt) { false }

      it "returns false" do
        expect(subject.apply_format_options!).to eq(false)
      end
    end

    context "when the partition has been set to be formatted or encrypted" do
      let(:format) { true }

      it "returns true" do
        expect(subject.apply_format_options!).to eq(true)
      end

      it "removes all partition descendants" do
        expect(partition).to receive(:remove_descendants).and_call_original
        subject.apply_format_options!
      end

      context "when the partition has been set to be encrypted" do
        let(:encrypt) { true }

        it "encrypts the partition" do
          expect(partition.encrypted?).to be(false)
          subject.apply_format_options!
          expect(partition.encryption.password).to eq(password)
        end
      end

      context "when the partition has been set to be formatted" do
        let(:format) { true }

        it "formats the partition" do
          previous_fs_sid = partition.filesystem.sid
          subject.apply_format_options!
          expect(partition.filesystem.sid).to_not eq(previous_fs_sid)
        end

        it "formats with the selected filesystem" do
          subject.apply_format_options!
          expect(partition.filesystem.type).to eq(filesystem_type)
        end

        context "and the filesystem is btrfs" do
          let(:filesystem_type) { Y2Storage::Filesystems::Type::BTRFS }

          it "ensures a default btrfs subvolume" do
            subject.apply_format_options!
            expect(partition.filesystem.default_btrfs_subvolume).to_not be_nil
          end
        end
      end
    end
  end

  context "#apply_mount_options!" do
    context "when the partiton has not filesystem" do
      before do
        allow(partition).to receive(:filesystem).and_return(nil)
      end

      it "returns false" do
        expect(subject.apply_mount_options!).to be(false)
      end
    end

    context "when the partition has a filesystem" do
      let(:filesystem) { partition.filesystem }

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

            it "does not delete the probed subvolumes" do
              subvolumes = filesystem.btrfs_subvolumes
              subject.apply_mount_options!

              expect(filesystem.btrfs_subvolumes).to include(*subvolumes)
            end

            it "updates the subvolumes mount points" do
              subject.apply_mount_options!
              mount_points = filesystem.btrfs_subvolumes.map(&:mount_point).compact
              expect(mount_points).to all(start_with(mount_point))
            end

            it "does not change mount point for special subvolumes" do
              subject.apply_mount_options!
              expect(filesystem.top_level_btrfs_subvolume.mount_point.to_s).to be_empty
              expect(filesystem.default_btrfs_subvolume.mount_point.to_s).to be_empty
            end

            it "refresh btrfs subvolumes shadowing" do
              expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
              subject.apply_mount_options!
            end

            context "and it has 'not probed' subvolumes" do
              let(:dev_name) { "/dev/sdb3" }
              let(:path) { "@/foo" }

              before do
                filesystem.create_btrfs_subvolume(path, false)
              end

              it "deletes the not probed subvolumes" do
                subject.apply_mount_options!
                expect(filesystem.find_btrfs_subvolume_by_path(path)).to be_nil
              end
            end

            context "and the new mount point is root" do
              let(:mount_point) { "/" }

              it "adds the proposed subvolumes for the current arch that do not exist" do
                specs = Y2Storage::SubvolSpecification.fallback_list
                arch_specs = Y2Storage::SubvolSpecification.for_current_arch(specs)
                paths = arch_specs.map { |s| filesystem.btrfs_subvolume_path(s.path) }

                expect(paths.any? { |p| filesystem.find_btrfs_subvolume_by_path(p).nil? }).to be(true)

                subject.apply_mount_options!

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
