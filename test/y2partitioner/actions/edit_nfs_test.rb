#!/usr/bin/env rspec
# Copyright (c) [2022] SUSE LLC
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
require "y2partitioner/device_graphs"
require "y2partitioner/actions/edit_nfs"

describe Y2Partitioner::Actions::EditNfs do
  before do
    devicegraph_stub("nfs1.xml")

    allow(Y2Partitioner::Dialogs::Nfs).to receive(:run) do |nfs_entry, _entries|
      nfs_entry.server = new_server
      nfs_entry.path = new_remote_path
      nfs_entry.mountpoint = new_mount_path

      dialog_result
    end
  end

  subject { described_class.new(nfs) }

  let(:nfs) { Y2Storage::Filesystems::Nfs.find_by_server_and_path(graph, "srv2", "/home/b") }
  let(:graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:new_mount_path) { "/the/local" }

  describe "#run" do
    context "if the user goes forward in the dialog" do
      let(:dialog_result) { :next }

      context "and the connection information for the NFS mount is not changed" do
        let(:new_server) { nfs.server }
        let(:new_remote_path) { nfs.path }

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end

        it "updates the NFS object with the corresponding data" do
          expect(nfs.mount_path).to_not eq new_mount_path
          subject.run
          expect(nfs.mount_path).to eq new_mount_path
        end
      end

      context "and the connection information for the NFS mount is changed" do
        let(:new_server) { "the_server" }
        let(:new_remote_path) { "/the/remote" }

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end

        it "replaces the NFS object with another one with the correct data" do
          sid = nfs.sid
          options = nfs.mount_options
          active = nfs.mount_point.active?
          expect(options).to_not be_empty

          subject.run

          expect(graph.find_device(sid)).to eq nil
          new_nfs = Y2Storage::Filesystems::Nfs.find_by_server_and_path(
            graph, new_server, new_remote_path
          )
          expect(new_nfs.mount_path).to eq new_mount_path
          expect(new_nfs.mount_options).to eq(options)
          expect(new_nfs.mount_point.active?).to eq(active)
        end
      end
    end

    context "if the dialog is discarded" do
      let(:dialog_result) { :back }

      let(:new_server) { "the_server" }
      let(:new_remote_path) { "/the/remote" }

      it "does not modify or add any NFS" do
        original_path = nfs.mount_path

        subject.run
        new_nfs = Y2Storage::Filesystems::Nfs.find_by_server_and_path(graph, new_server, new_remote_path)
        expect(new_nfs).to be_nil
        expect(nfs.mount_path).to eq original_path
      end

      it "returns nil" do
        expect(subject.run).to be_nil
      end
    end
  end
end
