#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/widgets/btrfs_options"
require "y2partitioner/actions/controllers/filesystem"

describe Y2Partitioner::Widgets::BtrfsOptions do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(controller) }

  let(:device) { fake_devicegraph.find_by_name(device_name) }

  let(:filesystem) { device.filesystem }

  let(:controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(filesystem, "") }

  let(:scenario) { "mixed_disks" }

  let(:device_name) { "/dev/sdb2" }

  include_examples "CWM::CustomWidget"

  it "includes a widget to configure mount options" do
    widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::MountOptions) }

    expect(widget).to_not be_nil
  end

  it "includes a widget to configure snapshots" do
    widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::Snapshots) }

    expect(widget).to_not be_nil
  end

  describe "#validate" do
    before do
      allow(subject).to receive(:filesystem_errors).and_return(warnings)

      allow(Yast2::Popup).to receive(:show)
        .with(anything, hash_including(headline: :warning)).and_return(accept)
    end

    let(:accept) { nil }

    context "if there are no warnings" do
      let(:warnings) { [] }

      it "does not show a warning popup" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.validate
      end

      it "returns true" do
        expect(subject.validate).to eq(true)
      end
    end

    context "if there are warnings" do
      let(:warnings) { ["warning1", "warning2"] }

      it "shows a warning popup" do
        expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :warning))

        subject.validate
      end

      context "and the user accepts" do
        let(:accept) { :yes }

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end

      context "and the user declines" do
        let(:accept) { :no }

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end
    end
  end

  describe "#filesystem_errors" do
    before do
      allow(Yast::Mode).to receive(:installation).and_return(installation)

      allow(filesystem).to receive(:configure_snapper).and_return(snapshots)

      allow(subject).to receive(:min_size_for_snapshots).and_return(needed_size)
    end

    let(:installation) { true }

    let(:needed_size) { 10.GiB }

    let(:errors) { subject.filesystem_errors(controller.filesystem, new_size: size) }

    context "when snapshots are not configured" do
      let(:snapshots) { false }

      let(:size) { 5.GiB }

      it "does not contain a size error" do
        expect(errors).to_not include(/small for snapshots/)
      end
    end

    context "when snaphots are configured" do
      let(:snapshots) { true }

      context "and the filesystem is a single-device Btrfs" do
        context "and the size is enough" do
          let(:size) { 15.GiB }

          it "does not contain a size error" do
            expect(errors).to_not include(/small for snapshots/)
          end
        end

        context "and the size is not enough" do
          let(:size) { 5.GiB }

          it "contains a size error" do
            expect(errors).to include(/small for snapshots/)
          end
        end
      end

      context "when the filesystem is a multi-device Btrfs" do
        let(:scenario) { "btrfs2-devicegraph.xml" }

        let(:device_name) { "/dev/sdb1" }

        let(:size) { 0.GiB }

        it "does not contain a size error" do
          expect(errors).to_not include(/small for snapshots/)
        end
      end
    end
  end

  describe "#refresh_others" do
    let(:mount_options_widget) { instance_double(Y2Partitioner::Widgets::MountOptions) }
    let(:snapshots_widget) { instance_double(Y2Partitioner::Widgets::Snapshots) }

    before do
      allow(Y2Partitioner::Widgets::MountOptions)
        .to receive(:new).and_return(mount_options_widget)

      allow(Y2Partitioner::Widgets::Snapshots)
        .to receive(:new).and_return(snapshots_widget)

      allow(snapshots_widget).to receive(:refresh)
      allow(snapshots_widget).to receive(:enable)
      allow(snapshots_widget).to receive(:disable)
    end

    context "when the MountOptions widget triggers an update" do
      it "does not call #refresh for the widget triggering the update" do
        expect(mount_options_widget).to_not receive(:refresh)

        subject.refresh_others(mount_options_widget)
      end

      it "calls #refresh for the Snapshots widget" do
        expect(snapshots_widget).to receive(:refresh)

        subject.refresh_others(mount_options_widget)
      end

      context "when snapshots can be configured" do
        before do
          allow(controller).to receive(:snapshots_supported?).and_return(true)
        end

        it "enables the Snapshots widget" do
          expect(snapshots_widget).to receive(:enable)

          subject.refresh_others(mount_options_widget)
        end
      end

      context "when snapshots cannot be configured" do
        before do
          allow(controller).to receive(:snapshots_supported?).and_return(false)
        end

        it "disables the Snapshots widget" do
          expect(snapshots_widget).to receive(:disable)

          subject.refresh_others(mount_options_widget)
        end

        it "resets the snapshots configuration" do
          controller.configure_snapper = true

          subject.refresh_others(mount_options_widget)

          expect(controller.configure_snapper).to eq(false)
        end
      end
    end

    context "when the Snapshots widget triggers an update" do
      it "does not call #refresh for the widget triggering the update" do
        expect(snapshots_widget).to_not receive(:refresh)

        subject.refresh_others(snapshots_widget)
      end

      it "does not call #refresh for the MountOptions widget" do
        expect(mount_options_widget).to_not receive(:refresh)

        subject.refresh_others(snapshots_widget)
      end
    end
  end
end
