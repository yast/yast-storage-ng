#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::AutoinstProfile::DriveSection do
  before { fake_scenario("autoyast_drive_examples") }

  def device(name)
    Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/#{name}")
  end

  describe ".new_from_hashes" do
    context "when type is not specified" do
      let(:hash) { {} }

      it "initializes it to :CT_DISK" do
        expect(described_class.new_from_hashes(hash).type).to eq(:CT_DISK)
      end

      context "and device is /dev/md" do
        let(:hash) { { "device" => "/dev/md" } }

        it "initializes it to :CT_MD" do
        expect(described_class.new_from_hashes(hash).type).to eq(:CT_MD)
        end
      end
    end
  end

  describe ".new_from_storage" do
    it "returns nil for a disk or DASD with no partitions" do
      expect(described_class.new_from_storage(device("dasda"))).to eq nil
      expect(described_class.new_from_storage(device("sda"))).to eq nil
    end

    it "returns nil for a disk or DASD with no exportable partitions" do
      expect(described_class.new_from_storage(device("sdb"))).to eq nil
    end

    it "returns a DriveSection object for a disk or DASD with exportable partitions" do
      expect(described_class.new_from_storage(device("dasdb"))).to be_a described_class
      expect(described_class.new_from_storage(device("sdc"))).to be_a described_class
    end

    it "stores the exportable partitions as PartitionSection objects" do
      section = described_class.new_from_storage(device("dasdb"))
      expect(section.partitions).to all(be_a(Y2Storage::AutoinstProfile::PartitionSection))
      expect(section.partitions.size).to eq 3

      section = described_class.new_from_storage(device("sdc"))
      expect(section.partitions).to all(be_a(Y2Storage::AutoinstProfile::PartitionSection))
      expect(section.partitions.size).to eq 2
    end

    context "for the extended partition" do
      it "considers the partition to not be exportable" do
        section = described_class.new_from_storage(device("sdd"))
        expect(section.partitions.map(&:partition_nr)).to_not include(4)
      end
    end

    context "for primary and logical partitions" do
      context "with a typical Windows partition id" do
        before do
          # SWIG makes very hard to use proper mocking here with
          # allow(a_partition).to(receive(:y)) because you can get different
          # Ruby wrapper objects for the same C++ partition. So let's simply
          # assign the values instead of intercepting the query calls.
          sdd1 = dev.partitions.find { |i| i.name == "/dev/sdd1" }
          sdd1.boot = true if bootable
          sdd1.filesystem.mountpoint = mountpoint if mountpoint
        end

        let(:dev) { device("sdd") }
        let(:mountpoint) { nil }

        context "and the boot flag enabled" do
          let(:bootable) { true }

          it "considers the partition to be exportable" do
            section = described_class.new_from_storage(dev)
            expect(section.partitions.map(&:partition_nr)).to include(1)
          end
        end

        context "that are mounted at /boot or some point below" do
          let(:bootable) { false }
          let(:mountpoint) { "/boot/something" }

          it "considers the partition to be exportable" do
            section = described_class.new_from_storage(dev)
            expect(section.partitions.map(&:partition_nr)).to include(1)
          end
        end

        context "that are not bootable or mounted under /boot" do
          let(:bootable) { false }

          it "considers the partition to not be exportable" do
            section = described_class.new_from_storage(dev)
            expect(section.partitions.map(&:partition_nr)).to_not include(1)
          end
        end
      end

      context "with a non-Windows partition id" do
        context "that can't be converted to PartitionSection object" do
          before do
            part_section_class = Y2Storage::AutoinstProfile::PartitionSection
            orig = part_section_class.method(:new_from_storage)

            allow(part_section_class).to receive(:new_from_storage) do |part|
              part.name == "/dev/sdd3" ? nil : orig.call(part)
            end
          end

          it "considers the partition to not be exportable" do
            section = described_class.new_from_storage(device("sdd"))
            expect(section.partitions.map(&:partition_nr)).to_not include(3)
          end
        end

        context "that can be converted to a PartitionSection object" do
          it "considers the partition to be exportable" do
            section = described_class.new_from_storage(device("sdd"))
            expect(section.partitions.map(&:partition_nr)).to include(3)
          end
        end
      end
    end

    it "initializes #type to :CT_DISK for both disks and DASDs" do
      expect(described_class.new_from_storage(device("dasdb")).type).to eq :CT_DISK
      expect(described_class.new_from_storage(device("sdc")).type).to eq :CT_DISK
    end

    describe "initializing DriveSection#device" do
      let(:dev) { device("sdd") }

      before do
        allow(Yast::Arch).to receive(:s390).and_return s390
        allow(dev).to receive(:udev_full_paths)
          .and_return ["/dev/disk/by-path/1", "/dev/disk/by-path/2"]
      end

      context "in s390" do
        let(:s390) { true }

        it "initializes #device to the udev path of the device" do
          section = described_class.new_from_storage(dev)
          expect(section.device).to eq "/dev/disk/by-path/1"
        end
      end

      context "in a non-s390 architecture" do
        let(:s390) { false }

        it "initializes #device to the kernel name of the device" do
          section = described_class.new_from_storage(dev)
          expect(section.device).to eq "/dev/sdd"
        end
      end
    end

    context "if there are no partitions with a typical Windows id in the disk" do
      let(:dev) { device("dasdb") }

      it "does not alter the initial value of #create for the partitions" do
        section = described_class.new_from_storage(dev)
        expect(section.partitions.map(&:create)).to all(eq(true))
      end

      it "initializes #use to 'all'" do
        section = described_class.new_from_storage(dev)
        expect(section.use).to eq "all"
      end
    end

    context "if there is some partition with a typical Windows id" do
      let(:dev) { device("sde") }

      before do
        # SWIG makes very hard to use proper mocking. See comment above.
        win = dev.partitions.first
        win.boot = true if bootable
        win.filesystem.mountpoint = mountpoint if mountpoint
      end

      let(:mountpoint) { nil }
      let(:bootable) { false }

      context "and the Windows-alike partition is marked with the boot flag" do
        let(:bootable) { true }

        it "initializes #use to 'all'" do
          section = described_class.new_from_storage(dev)
          expect(section.use).to eq "all"
        end

        it "does not alter the initial value of #create for the partitions" do
          section = described_class.new_from_storage(dev)
          expect(section.partitions.map(&:create)).to all(eq(true))
        end
      end

      context "and the Windows-alike partitions is mounted at /boot or below" do
        let(:mountpoint) { "/boot" }

        it "initializes #use to 'all'" do
          section = described_class.new_from_storage(dev)
          expect(section.use).to eq "all"
        end

        it "does not alter the initial value of #create for the partitions" do
          section = described_class.new_from_storage(dev)
          expect(section.partitions.map(&:create)).to all(eq(true))
        end
      end

      context "and the Windows partition is not marked as bootable nor mounted at /boot" do
        it "initializes #use to the list of exported partition numbers" do
          section = described_class.new_from_storage(dev)
          expect(section.use).to eq "2,3"
        end

        context "and the Windows partition(s) are the first partitions in the disk" do
          it "does not alter the initial value of #create for the partitions" do
            section = described_class.new_from_storage(dev)
            expect(section.partitions.map(&:create)).to all(eq(true))
          end
        end

        context "and there is any non-Windows partition before it in the disk" do
          context "if the non-Windows partition is an extended one" do
            let(:dev) { device("sdf") }

            it "does not alter the initial value of #create for the partitions" do
              section = described_class.new_from_storage(dev)
              expect(section.partitions.map(&:create)).to all(eq(true))
            end
          end

          context "if the non-Windows partition is not extended" do
            let(:dev) { device("sdd") }

            it "sets #create to false for all the partitions" do
              section = described_class.new_from_storage(dev)
              expect(section.partitions.map(&:create)).to all(eq(false))
            end
          end
        end
      end
    end
  end

  describe "#to_hashes" do
    subject(:section) { described_class.new }

    it "returns a hash with all the non-blank values using strings as keys" do
      section.type = :CT_DISK
      section.use = "all"
      expect(section.to_hashes).to eq("type" => :CT_DISK, "use" => "all")
    end

    it "returns an empty hash if all the values are blank" do
      expect(section.to_hashes).to eq({})
    end

    it "exports #initialize_attr as 'initialize'" do
      section.initialize_attr = true
      hash = section.to_hashes
      expect(hash.keys).to include "initialize"
      expect(hash.keys).to_not include "initialize_attr"
      expect(hash["initialize"]).to eq true
    end

    it "does not export nil values" do
      section.disklabel = nil
      section.is_lvm_vg = nil
      section.partitions = nil
      hash = section.to_hashes
      expect(hash.keys).to_not include "disklabel"
      expect(hash.keys).to_not include "is_lvm_vg"
      expect(hash.keys).to_not include "partitions"
    end

    it "does not export empty collections (#partitions and #skip_list)" do
      section.partitions = []
      section.skip_list = []
      hash = section.to_hashes
      expect(hash.keys).to_not include "partitions"
      expect(hash.keys).to_not include "skip_list"
    end

    it "exports #partitions and #skip_list as arrays of hashes" do
      part1 = Y2Storage::AutoinstProfile::PartitionSection.new
      part1.create = true
      section.partitions << part1
      part2 = Y2Storage::AutoinstProfile::PartitionSection.new
      part2.create = false
      section.partitions << part2
      rule = instance_double(Y2Storage::AutoinstProfile::SkipRule, to_profile_rule: {})
      section.skip_list = Y2Storage::AutoinstProfile::SkipListSection.new([rule])

      hash = section.to_hashes

      expect(hash["partitions"]).to be_a(Array)
      expect(hash["partitions"].size).to eq 2
      expect(hash["partitions"]).to all(be_a(Hash))

      expect(hash["skip_list"]).to be_a(Array)
      expect(hash["skip_list"].size).to eq 1
      expect(hash["skip_list"].first).to be_a Hash
    end

    it "exports false values" do
      section.is_lvm_vg = false
      hash = section.to_hashes
      expect(hash.keys).to include "is_lvm_vg"
      expect(hash["is_lvm_vg"]).to eq false
    end

    it "does not export empty strings" do
      section.device = ""
      expect(section.to_hashes.keys).to_not include "device"
    end
  end
end
