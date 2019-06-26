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
require "y2storage"
require "y2partitioner/dialogs/format_and_mount"
require "y2partitioner/actions/controllers"

describe Y2Partitioner::Dialogs::FormatAndMount do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:blk_device) { Y2Storage::Partition.find_by_name(fake_devicegraph, "/dev/sda1") }
  let(:controller) do
    Y2Partitioner::Actions::Controllers::Filesystem.new(blk_device, "")
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::FormatAndMount::FormatMountOptions do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

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

    describe "#refresh_others" do
      let(:format_widget) { double("FormatOptions") }
      let(:mount_widget) { double("MountOptions") }

      before do
        allow(Y2Partitioner::Widgets::FormatOptions).to receive(:new).and_return format_widget
        allow(Y2Partitioner::Widgets::MountOptions).to receive(:new).and_return mount_widget
        allow(format_widget).to receive(:refresh)
        allow(mount_widget).to receive(:refresh)
      end

      context "when the FormatOptions widget triggers an update" do
        it "does not call #refresh for the widget triggering the update" do
          expect(format_widget).to_not receive(:refresh)
          widget.refresh_others(format_widget)
        end

        it "calls #refresh for the widget not triggering the update" do
          expect(mount_widget).to receive(:refresh)
          widget.refresh_others(format_widget)
        end
      end

      context "when the MountOptions widget triggers an update" do
        it "does not call #refresh for the widget triggering the update" do
          expect(mount_widget).to_not receive(:refresh)
          widget.refresh_others(mount_widget)
        end

        it "calls #refresh for the widget not triggering the update" do
          expect(format_widget).to receive(:refresh)
          widget.refresh_others(mount_widget)
        end
      end
    end
  end
end
