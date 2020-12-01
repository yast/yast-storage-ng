#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/actions/delete_tmpfs"

describe Y2Partitioner::Actions::DeleteTmpfs do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(filesystem) }

  let(:filesystem) { device_graph.tmp_filesystems.find { |f| f.mount_path == mount_path } }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "tmpfs1-devicegraph.xml" }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show).and_return(accept)
    end

    let(:accept) { nil }

    shared_examples "do not delete" do
      it "does not delete the filesystem" do
        subject.run

        fs = device_graph.tmp_filesystems.find { |f| f.mount_path == mount_path }

        expect(fs).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    shared_examples "confirm and delete" do
      it "shows a confirm message" do
        expect(Yast2::Popup).to receive(:show).with(/delete the temporary file system/, anything)
        subject.run
      end

      context "when the confirm message is not accepted" do
        let(:accept) { :no }

        include_examples "do not delete"
      end

      context "when the confirm message is accepted" do
        let(:accept) { :yes }

        it "deletes the filesystem" do
          subject.run

          fs = device_graph.tmp_filesystems.find { |f| f.mount_path == mount_path }

          expect(fs).to be_nil
        end

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end
      end
    end

    context "when the filesystem is not mounted in the system" do
      let(:mount_path) { "/test2" }

      it "does not ask for unmounting the partition" do
        expect(Yast2::Popup).to_not receive(:show).with(/try to unmount/, anything)

        subject.run
      end

      include_examples "confirm and delete"
    end

    context "when the filesystem is mounted in the system" do
      let(:mount_path) { "/test1" }

      before do
        allow(Yast2::Popup).to receive(:show).with(/try to unmount/, anything)
          .and_return(*unmount_answer)
      end

      let(:unmount_answer) { [:cancel] }

      it "asks for unmounting the filesystem" do
        expect(Yast2::Popup).to receive(:show).with(/try to unmount/, anything)

        subject.run
      end

      it "shows a specific note for deleting" do
        expect(Yast2::Popup).to receive(:show)
          .with(/cannot be deleted while mounted/, anything)
          .and_return(:cancel)

        subject.run
      end

      context "and the user decides to continue" do
        let(:unmount_answer) { [:continue] }

        include_examples "confirm and delete"
      end

      context "and the user decides to cancel" do
        let(:unmount_answer) { [:cancel] }

        include_examples "do not delete"
      end
    end
  end
end
