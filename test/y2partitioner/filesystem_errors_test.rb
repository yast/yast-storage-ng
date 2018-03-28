#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/filesystem_errors"

describe Y2Partitioner::FilesystemErrors do
  using Y2Storage::Refinements::SizeCasts

  # Dummy class to test the mixin
  class FilesystemChecker
    include Y2Partitioner::FilesystemErrors
  end

  let(:checker) { FilesystemChecker.new }

  describe "#filesystem_errors" do
    def create_partition(size)
      disk = fake_devicegraph.find_by_name("/dev/sda")
      ptable = disk.partition_table
      ptable.create_partition(
        "/dev/sda1",
        Y2Storage::Region.create(0, size.to_i / 512, 512),
        Y2Storage::PartitionType::PRIMARY
      )
    end

    before do
      allow(Yast::Mode).to receive(:installation).and_return(installation)
      allow(Y2Storage::VolumeSpecification).to receive(:for).and_return(nil)
      allow(Y2Storage::VolumeSpecification).to receive(:for).with("/").and_return(root_spec)

      fake_scenario("empty_hard_disk_gpt_50GiB")
      create_partition(partition_size)
    end

    let(:installation) { nil }

    let(:root_spec) do
      instance_double(Y2Storage::VolumeSpecification, min_size_with_snapshots: root_spec_min_size)
    end

    let(:root_spec_min_size) { 10.GiB }

    let(:partition_size) { 20.GiB }

    let(:new_size) { nil }

    let(:partition) { fake_devicegraph.find_by_name("/dev/sda1") }

    shared_examples "no snapshots error" do
      it "does not contain 'small device for snapshots' error" do
        expect(checker.filesystem_errors(filesystem, new_size: new_size))
          .to_not include(/small for snapshots/)
      end
    end

    shared_examples "snapshots error" do
      it "contains 'small device for snapshots' error" do
        expect(checker.filesystem_errors(filesystem, new_size: new_size))
          .to include(/small for snapshots/)
      end
    end

    context "if no filesystem is given" do
      let(:filesystem) { nil }

      it "returns an empty list" do
        expect(checker.filesystem_errors(filesystem)).to be_empty
      end
    end

    context "if a filesystem is given" do
      let(:filesystem) { partition.create_filesystem(fs_type) }

      let(:fs_type) { Y2Storage::Filesystems::Type::BTRFS }

      context "and the mode is not installation" do
        let(:installation) { false }

        include_examples "no snapshots error"
      end

      context "and the mode is installation" do
        let(:installation) { true }

        context "and the filesystem is not btrfs" do
          let(:fs_type) { Y2Storage::Filesystems::Type::EXT4 }

          include_examples "no snapshots error"
        end

        context "and the filesystem is btrfs" do
          let(:fs_type) { Y2Storage::Filesystems::Type::BTRFS }

          context "and it is not configured to have snapshots" do
            before do
              filesystem.configure_snapper = false
            end

            include_examples "no snapshots error"
          end

          context "and it is configured to have snapshots" do
            before do
              filesystem.configure_snapper = true
            end

            context "and there is no volume specification for the device" do
              before do
                filesystem.mount_path = "/foo"
              end

              include_examples "no snapshots error"
            end

            context "and there is a volume specification for the device" do
              before do
                filesystem.mount_path = "/"
              end

              context "and a specific new size is given" do
                let(:partition_size) { 1.GiB }

                let(:root_spec_min_size) { 10.GiB }

                context "and the given size is bigger than the specification size" do
                  let(:new_size) { 11.GiB }

                  include_examples "no snapshots error"
                end

                context "and the given size is equal to the specification size" do
                  let(:new_size) { 10.GiB }

                  include_examples "no snapshots error"
                end

                context "and the given size is less than the specification size" do
                  let(:new_size) { 9.GiB }

                  include_examples "snapshots error"
                end
              end

              context "and no specific new size is given" do
                let(:new_size) { nil }

                let(:root_spec_min_size) { 10.GiB }

                context "and the filesystem size is bigger than the specification size" do
                  let(:partition_size) { 11.GiB }

                  include_examples "no snapshots error"
                end

                context "and the filesystem size is equal to the specification size" do
                  let(:partition_size) { 10.GiB }

                  include_examples "no snapshots error"
                end

                context "and the filesystem size is less than the specification size" do
                  let(:new_size) { 9.GiB }

                  include_examples "snapshots error"
                end
              end
            end
          end
        end
      end
    end
  end
end
