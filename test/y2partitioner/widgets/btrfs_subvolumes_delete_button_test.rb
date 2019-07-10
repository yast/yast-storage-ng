#!/usr/bin/env rspec

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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/btrfs_subvolumes_delete_button"

describe Y2Partitioner::Widgets::BtrfsSubvolumesDeleteButton do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  subject { described_class.new(table) }

  let(:table) do
    instance_double(
      Y2Partitioner::Widgets::BtrfsSubvolumesTable,
      filesystem:         filesystem,
      selected_subvolume: selected_subvolume,
      refresh:            nil
    )
  end

  let(:selected_subvolume) { filesystem.btrfs_subvolumes.detect { |s| s.path == "@/home" } }

  let(:filesystem) do
    device_graph = Y2Partitioner::DeviceGraphs.instance.current
    Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/sda2").filesystem
  end

  before do
    allow(Yast::Popup).to receive(:YesNo).and_return(result)
  end

  let(:result) { false }

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when there is no selected subvolume in the table" do
      let(:selected_subvolume) { nil }

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        subject.handle
      end
    end

    context "when there is a selected subvolume" do
      it "asks for confirmation to delete the selected subvolume" do
        expect(Yast::Popup).to receive(:YesNo)
        subject.handle
      end

      context "and the confirm dialog is accepted" do
        let(:result) { true }

        it "deletes the subvolume" do
          expect(filesystem.btrfs_subvolumes).to include(selected_subvolume)

          deleted_path = selected_subvolume.path
          subject.handle

          expect(filesystem.btrfs_subvolumes.map(&:path)).to_not include(deleted_path)
        end

        it "refreshes the table" do
          expect(table).to receive(:refresh)
          subject.handle
        end
      end

      context "and the confirm dialog is not accepted" do
        let(:result) { false }

        it "does not delete the subvolume" do
          expect(filesystem.btrfs_subvolumes).to include(selected_subvolume)
          subject.handle
          expect(filesystem.btrfs_subvolumes).to include(selected_subvolume)
        end

        it "does not refresh the table" do
          expect(table).to_not receive(:refresh)
          subject.handle
        end
      end
    end
  end
end
