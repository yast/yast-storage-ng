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
require "y2partitioner/actions/add_nfs"

describe Y2Partitioner::Actions::AddNfs do
  before do
    devicegraph_stub("nfs1.xml")

    allow(Y2Partitioner::Dialogs::Nfs).to receive(:run) do |nfs, _entries|
      nfs.server = new_server
      nfs.path = new_remote_path
      nfs.mountpoint = new_mount_path

      dialog_result
    end
  end

  subject { described_class.new }

  let(:new_server) { "the_server" }
  let(:new_remote_path) { "/the/remote" }
  let(:new_mount_path) { "/the/local" }
  let(:graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    context "if the user goes forward in the dialog" do
      let(:dialog_result) { :next }

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end

      it "creates the new NFS with the proper attributes" do
        nfs = Y2Storage::Filesystems::Nfs.find_by_server_and_path(graph, new_server, new_remote_path)
        expect(nfs).to be_nil

        subject.run

        nfs = Y2Storage::Filesystems::Nfs.find_by_server_and_path(graph, new_server, new_remote_path)
        expect(nfs).to be_a(Y2Storage::Filesystems::Nfs)
        expect(nfs.mount_path).to eq new_mount_path
      end
    end

    context "if the dialog is discarded" do
      let(:dialog_result) { :back }

      it "does not create a new NFS" do
        before = graph.nfs_mounts.size
        subject.run
        after = graph.nfs_mounts.size

        expect(before).to eq after
      end

      it "returns nil" do
        expect(subject.run).to be_nil
      end
    end
  end
end
