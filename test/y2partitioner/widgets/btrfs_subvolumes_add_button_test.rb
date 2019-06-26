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
require "y2partitioner/widgets/btrfs_subvolumes_add_button"

describe Y2Partitioner::Widgets::BtrfsSubvolumesAddButton do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
    allow(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new).and_return(dialog)
  end

  let(:dialog) { instance_double(Y2Partitioner::Dialogs::BtrfsSubvolume, run: result, form: form) }

  let(:result) { :cancel }

  let(:form) { nil }

  subject { described_class.new(table) }

  let(:table) do
    instance_double(Y2Partitioner::Widgets::BtrfsSubvolumesTable, filesystem: filesystem, refresh: nil)
  end

  let(:filesystem) do
    device_graph = Y2Partitioner::DeviceGraphs.instance.current
    Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/sda2").filesystem
  end

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "shows a dialog to create a new btrfs subvolume" do
      expect(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new)
      expect(dialog).to receive(:run)

      subject.handle
    end

    context "when the dialog is accepted" do
      let(:result) { :ok }

      let(:form) { double("dialog form", path: "@/foo", nocow: true) }

      it "creates a new subvolume with correct path and nocow attribute" do
        subvolumes = filesystem.btrfs_subvolumes
        expect(subvolumes.map(&:path)).to_not include(form.path)

        subject.handle

        expect(filesystem.btrfs_subvolumes.size > subvolumes.size).to be(true)

        subvolume = filesystem.btrfs_subvolumes.detect { |s| s.path == form.path }
        expect(subvolume).to_not be_nil
        expect(subvolume.nocow?).to eq(form.nocow)
      end

      it "creates a new subvolume with correct mount point" do
        mountpoint = File.join(filesystem.mount_path, "foo")

        subvolumes = filesystem.btrfs_subvolumes
        expect(subvolumes.map(&:mount_path)).to_not include(mountpoint)

        subject.handle

        expect(filesystem.btrfs_subvolumes.map(&:mount_path)).to include(mountpoint)
      end

      it "refreshes the table" do
        expect(table).to receive(:refresh)
        subject.handle
      end

      context "if the subvolume is shadowed" do
        let(:form) { double("dialog form", path: "@/mnt/foo", nocow: true) }

        before do
          allow(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new)
            .and_return(dialog, second_dialog)
        end
        let(:second_dialog) { instance_double(Y2Partitioner::Dialogs::BtrfsSubvolume, run: :cancel) }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error)
          subject.handle
        end

        it "opens the Btrfs dialog again prefilled with the same information" do
          expect(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new).with(filesystem, nil).ordered
            .and_return(dialog)
          expect(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new).with(filesystem, form).ordered
            .and_return(second_dialog)

          subject.handle
        end

        it "does not create a new subvolume" do
          subvolumes = filesystem.btrfs_subvolumes
          expect(subvolumes.map(&:path)).to_not include(form.path)

          subject.handle

          expect(filesystem.btrfs_subvolumes.size).to eq subvolumes.size
          expect(filesystem.btrfs_subvolumes.map(&:path)).to_not include(form.path)
        end
      end
    end

    context "when the dialog is not accepted" do
      let(:result) { :cancel }

      it "does not create a new subvolume" do
        subvolumes = filesystem.btrfs_subvolumes
        subject.handle

        expect(filesystem.btrfs_subvolumes).to eq(subvolumes)
      end

      it "does not refresh the table" do
        expect(table).to_not receive(:refresh)
        subject.handle
      end
    end
  end
end
