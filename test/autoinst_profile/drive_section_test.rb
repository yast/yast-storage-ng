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
        expect(Yast::Arch).to receive(:s390).and_return s390
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
      it "does not alter the initial value of #create for the partitions" do
        skip
      end

      it "initializes #use to 'all'" do
        skip
      end
    end

    context "if there is some partition with a typical Windows id" do
      context "and the Windows-alike partition is marked with the boot flag" do
        it "initializes #use to 'all'" do
          skip
        end

        it "does not alter the initial value of #create for the partitions" do
          skip
        end
      end

      context "and the Windows-alike partitions is mounted at /boot or below" do
        it "initializes #use to 'all'" do
          skip
        end

        it "does not alter the initial value of #create for the partitions" do
          skip
        end
      end

      context "and the Windows partition is not marked as bootable nor mounted at /boot" do
        it "initializes #use to the list of exported partition numbers" do
          skip
        end

        context "and there is any non-Windows partition before it in the disk" do
          it "sets #create to false for all the partitions" do
            skip
          end
        end

        context "and the Windows partition(s) are the first partitions in the disk" do
          it "does not alter the initial value of #create for the partitions" do
            skip
          end
        end
      end
    end
  end
end
