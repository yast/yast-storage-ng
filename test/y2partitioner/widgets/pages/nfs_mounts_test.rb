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
# find current contact information at www.suse.com

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::NfsMounts do
  before do
    devicegraph_stub("nfs1.xml")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject(:nfs_page) { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }
  let(:client_name) { "nfs-client4part" }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:legacy_shares) do
      [
        { "device" => "srv:/home/a", "mount" => "/test1", "fstopt" => "defaults", "used_fs" => :nfs },
        {
          "device" => "srv2:/home/b", "mount" => "/test2", "used_fs" => :nfs,
          "fstopt" => "rw,relatime,vers=3,rsize=65536,wsize=65536"
        }
      ]
    end

    before do
      allow(Yast::Stage).to receive(:initial).and_return in_installation
      allow(Yast::WFM).to receive(:ClientExists).and_return client_exists
      Y2Partitioner::YastNfsClient.reset
    end

    # Whether the term includes, at some point, the error about missing client
    def includes_error_msg?(term)
      found = term.nested_find do |content|
        content =~ /NFS configuration is not available/
      end
      !found.nil?
    end

    RSpec.shared_examples "delegated UI" do
      let(:ui) { double("Yast::Term") }

      before do
        allow(Yast::WFM).to receive(:CallFunction).with(client_name, ["CreateUI"]).and_return(ui)
      end

      it "passes the list of NFS mounts to the YaST client in the expected format" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with(client_name, ["FromStorage", "shares" => legacy_shares])
        nfs_page.contents
      end

      it "includes the UI provided by the YaST client" do
        ui_in_content = nfs_page.contents.nested_find { |i| i == ui }
        expect(ui_in_content).to_not be nil
      end

      it "does not include the error message about missing client" do
        expect(includes_error_msg?(nfs_page.contents)).to eq false
      end
    end

    context "during installation" do
      let(:in_installation) { true }

      context "if the YaST client from y2-nfs-client is available" do
        let(:client_exists) { true }

        before do
          allow(Yast::WFM).to receive(:CallFunction).with(client_name, anything)
        end

        it "does not try to install any package" do
          expect(Yast::PackageSystem).to_not receive(:CheckAndInstallPackages)
          nfs_page.contents
        end

        it "does not read the NFS system configuration" do
          expect(Yast::WFM).to_not receive(:CallFunction).with(client_name, ["Read"])
          nfs_page.contents
        end

        include_examples "delegated UI"
      end

      context "if the YaST client from y2-nfs-client is not available" do
        let(:client_exists) { false }

        it "does not try to install any package" do
          expect(Yast::PackageSystem).to_not receive(:CheckAndInstallPackages)
          nfs_page.contents
        end

        it "does not read the NFS system configuration" do
          expect(Yast::WFM).to_not receive(:CallFunction).with(client_name, ["Read"])
          nfs_page.contents
        end

        it "does not call the client for any other purpose" do
          expect(Yast::WFM).to_not receive(:CallFunction)
          nfs_page.contents
        end

        it "includes the error message about missing client" do
          expect(includes_error_msg?(nfs_page.contents)).to eq true
        end
      end
    end

    context "in an installed system" do
      let(:in_installation) { false }

      before do
        allow(Yast::PackageCallbacks).to receive(:RegisterEmptyProgressCallbacks)
        allow(Yast::PackageCallbacks).to receive(:RestorePreviousProgressCallbacks)
      end

      context "if the YaST client from y2-nfs-client is available" do
        let(:client_exists) { true }

        before do
          allow(Yast::WFM).to receive(:CallFunction).with(client_name, anything)
        end

        it "does not try to install any package" do
          expect(Yast::PackageSystem).to_not receive(:CheckAndInstallPackages)
          nfs_page.contents
        end

        it "reads the NFS system configuration once" do
          expect(Yast::WFM).to receive(:CallFunction).with(client_name, ["Read"]).once
          nfs_page.contents
        end

        include_examples "delegated UI"
      end

      context "if the YaST client from y2-nfs-client is not available" do
        let(:client_exists) { false }

        it "tries to install yast2-nfs-client" do
          expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages)
            .with(["yast2-nfs-client"])
          nfs_page.contents
        end

        context "and installation of yast2-nfs-client suceeds" do
          before do
            allow(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return true
            allow(Yast::WFM).to receive(:CallFunction).with(client_name, anything)
          end

          it "reads the NFS system configuration once" do
            expect(Yast::WFM).to receive(:CallFunction).with(client_name, ["Read"]).once
            nfs_page.contents
          end

          include_examples "delegated UI"
        end

        context "and it does not manage to install yast2-nfs-client" do
          before do
            allow(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return false
          end

          it "does not read the NFS system configuration" do
            expect(Yast::WFM).to_not receive(:CallFunction).with(client_name, ["Read"])
            nfs_page.contents
          end

          it "does not call the client for any other purpose" do
            expect(Yast::WFM).to_not receive(:CallFunction)
            nfs_page.contents
          end

          it "includes the error message about missing client" do
            expect(includes_error_msg?(nfs_page.contents)).to eq true
          end
        end
      end
    end
  end

  describe "#handle" do
    before do
      allow(Yast::WFM).to receive(:ClientExists).and_return true
      # Just to prevent it from trying to read NFS configuration
      allow(Yast::Stage).to receive(:initial).and_return true
    end

    context "when the event is not related to the add/edit/delete buttons" do
      let(:event) do
        { "EventType" => "WidgetEvent", "EventReason" => "SelectionChanged", "ID" => :fstable }
      end

      it "does not call the client" do
        expect(Yast::WFM).to_not receive(:CallFunction)
        nfs_page.handle(event)
      end
    end

    context "when the event is triggered by the 'add' button" do
      let(:event) do
        { "EventType" => "WidgetEvent", "EventReason" => "Activated", "ID" => :newbut }
      end

      before do
        allow(Yast::WFM).to receive(:CallFunction).and_return client_result
        allow_any_instance_of(Y2Storage::Filesystems::Nfs).to receive(:detect_space_info)
      end

      let(:client_result) do
        {
          "device" => "srv:/home/b", "fstopt" => "rw,minorversion=1", "mount" => "/mnt/b",
          "old_device" => "", "vfstype" => "nfs"
        }
      end

      it "notifies the event to the YaST client" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with(client_name, ["HandleEvent", "widget_id" => :newbut])
        nfs_page.handle(event)
      end

      context "but the action is cancelled" do
        let(:client_result) { {} }

        it "does not modify the devicegraph" do
          list_before = device_graph.nfs_mounts
          nfs_page.handle(event)
          expect(device_graph.nfs_mounts).to eq list_before
        end
      end

      context "and it's possible to perform a test mount for the new NFS share" do

        it "adds the new NFS mount to the current devicegraph" do
          list_before = device_graph.nfs_mounts
          nfs_page.handle(event)
          list_after = device_graph.nfs_mounts

          expect(list_after.size).to eq(list_before.size + 1)

          new_nfs = list_after.find do |nfs|
            nfs.server == "srv" &&
              nfs.path == "/home/b" &&
              nfs.mount_point &&
              nfs.mount_point.path == "/mnt/b" &&
              nfs.mount_point.mount_options == ["rw", "minorversion=1"]
          end

          expect(new_nfs).to_not be_nil
        end
      end

      context "but performing a test mount for the NFS share fails" do
        before do
          allow_any_instance_of(Y2Storage::Filesystems::Nfs).to receive(:detect_space_info)
            .and_raise Storage::Exception
        end

        it "asks the user whether to add the mount anyway" do
          expect(Yast::Popup).to receive(:YesNo).with(/Save it anyway\?/)
          nfs_page.handle(event)
        end

        context "and the user decides to proceed" do
          before { allow(Yast::Popup).to receive(:YesNo).and_return true }

          it "adds the new NFS mount to the current devicegraph" do
            list_before = device_graph.nfs_mounts
            nfs_page.handle(event)
            list_after = device_graph.nfs_mounts

            expect(list_after.size).to eq(list_before.size + 1)

            new_nfs = list_after.find do |nfs|
              nfs.server == "srv" &&
                nfs.path == "/home/b" &&
                nfs.mount_point &&
                nfs.mount_point.path == "/mnt/b" &&
                nfs.mount_point.mount_options == ["rw", "minorversion=1"]
            end

            expect(new_nfs).to_not be_nil
          end
        end

        context "and the user decides to cancel" do
          before { allow(Yast::Popup).to receive(:YesNo).and_return false }

          it "does not modify the devicegraph" do
            list_before = device_graph.nfs_mounts
            nfs_page.handle(event)
            expect(device_graph.nfs_mounts).to eq list_before
          end
        end
      end
    end

    context "when the event is triggered by the 'delete' button" do
      let(:event) do
        { "EventType" => "WidgetEvent", "EventReason" => "Activated", "ID" => :delbut }
      end

      before do
        allow(Yast::WFM).to receive(:CallFunction).and_return client_result
      end

      let(:client_result) { nil }

      it "notifies the event to the YaST client" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with(client_name, ["HandleEvent", "widget_id" => :delbut])
        nfs_page.handle(event)
      end

      context "but the action is cancelled" do
        let(:client_result) { {} }

        it "does not modify the devicegraph" do
          list_before = device_graph.nfs_mounts
          nfs_page.handle(event)
          expect(device_graph.nfs_mounts).to eq list_before
        end
      end

      context "and the action is confirmed" do
        let(:client_result) do
          {
            "device" => "srv:/home/a", "fstopt" => "defaults", "mount" => "/test1", "vfstype" => "nfs"
          }
        end

        it "removes the affected NFS mount from the current devicegraph" do
          list_before = device_graph.nfs_mounts
          nfs_page.handle(event)
          list_after = device_graph.nfs_mounts

          expect(list_after.size).to eq(list_before.size - 1)
          expect(list_after).to_not include(
            an_object_having_attributes(server: "srv", path: "/home/a")
          )
        end
      end
    end

    context "when the event is triggered by the 'edit' button" do
      let(:event) do
        { "EventType" => "WidgetEvent", "EventReason" => "Activated", "ID" => :editbut }
      end

      it "notifies the event to the YaST client" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with(client_name, ["HandleEvent", "widget_id" => :editbut])
        nfs_page.handle(event)
      end

      context "and the legacy NFSv4 options are modified" do
        before do
          allow(Yast::WFM).to receive(:CallFunction).and_return client_result
          # Simulate a legacy nfs4 entry
          nfs_object.mount_point.mount_type = Y2Storage::Filesystems::Type::NFS4
        end

        let(:nfs_object) { device_graph.nfs_mounts.find { |nfs| nfs.path == "/home/a" } }

        let(:client_result) do
          {
            "device" => "srv:/home/a", "fstopt" => "nfsvers=4", "mount" => "/test1",
            "vfstype" => "nfs"
          }
        end

        it "edits the NFS mount in the current devicegraph" do
          expect(nfs_object.mount_point.mount_type.to_sym).to eq :nfs4
          expect(nfs_object.mount_point.mount_options).to be_empty

          nfs_page.handle(event)

          expect(nfs_object.mount_point.mount_type.to_sym).to eq :nfs
          expect(nfs_object.mount_point.mount_options).to eq ["nfsvers=4"]
        end
      end
    end
  end
end
