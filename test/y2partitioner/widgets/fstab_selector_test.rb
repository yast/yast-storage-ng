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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/fstab_selector"
require "y2partitioner/actions/controllers/fstabs"

describe Y2Partitioner::Widgets::FstabSelector do
  def button(contents, id)
    contents.nested_find do |widget|
      widget.is_a?(Yast::Term) &&
        widget.value == :PushButton &&
        widget.params.first.params.include?(id)
    end
  end

  def filesystem(device_name)
    device = Y2Partitioner::DeviceGraphs.instance.current.find_by_name(device_name)
    device.filesystem
  end

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Actions::Controllers::Fstabs.new }

  before do
    devicegraph_stub("mixed_disks.yml")

    allow(controller).to receive(:fstabs).and_return(fstabs)

    allow(fstab1).to receive(:entries).and_return(fstab1_entries)
    allow(fstab2).to receive(:entries).and_return(fstab2_entries)
    allow(fstab3).to receive(:entries).and_return(fstab3_entries)

    allow(Yast::UI).to receive(:ChangeWidget).and_call_original

    controller.selected_fstab = selected_fstab
  end

  let(:fstab1) { Y2Storage::Fstab.new("", filesystem("/dev/sda2")) }
  let(:fstab2) { Y2Storage::Fstab.new("", filesystem("/dev/sdb2")) }
  let(:fstab3) { Y2Storage::Fstab.new("", filesystem("/dev/sdb6")) }

  let(:fstab1_entries) do
    [
      fstab_entry("/dev/sda2", "/", ext4, [], 0, 0),
      fstab_entry("/dev/sdb2", "/home", ext4, [], 0, 0)
    ]
  end

  let(:fstab2_entries) do
    [
      fstab_entry("/dev/sda2", "/", ext4, [], 0, 0)
    ]
  end

  let(:fstab3_entries) do
    [
      fstab_entry("/dev/unknown", "/", ext4, [], 0, 0)
    ]
  end

  let(:ext4) { Y2Storage::Filesystems::Type::EXT4 }

  let(:fstabs) { [fstab1, fstab2, fstab3] }

  let(:selected_fstab) { fstab1 }

  include_examples "CWM::CustomWidget"

  describe "#init" do
    let(:selected_fstab) { nil }

    it "selects the first fstab" do
      subject.init

      expect(controller.selected_fstab).to eq(fstabs.first)
    end

    it "disables button to 'select previous' fstab" do
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:show_prev), :Enabled, false)

      subject.init
    end

    context "when there is only one fstab" do
      let(:fstabs) { [fstab1] }

      it "disables button to 'select next' fstab" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:show_next), :Enabled, false)

        subject.init
      end
    end

    context "when there are several fstabs" do
      let(:fstabs) { [fstab1, fstab2] }

      it "does not disable button to 'select next' fstab" do
        expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(:show_next), :Enabled, false)

        subject.init
      end
    end
  end

  describe "#contents" do
    let(:selected_fstab) { fstab1 }

    it "shows the selected fstab" do
      expect(Y2Partitioner::Widgets::FstabSelector::FstabContent).to receive(:new)
        .with(controller.selected_fstab)

      subject.contents
    end

    it "shows buttons to switch between fstabs" do
      expect(button(subject.contents, :show_prev)).to_not be_nil
      expect(button(subject.contents, :show_next)).to_not be_nil
    end
  end

  describe "#handle" do
    let(:event) { { "ID" => button } }

    context "when 'show prev' button is selected" do
      let(:selected_fstab) { fstab2 }

      let(:button) { :show_prev }

      it "selects the previous fstab" do
        subject.handle(event)

        expect(controller.selected_fstab).to eq(fstab1)
      end

      context "when the previous fstab is the first one" do
        let(:selected_fstab) { fstab2 }

        it "disables button to 'select previous' fstab" do
          expect(Yast::UI).to receive(:ChangeWidget).with(Id(:show_prev), :Enabled, false)

          subject.handle(event)
        end
      end

      context "when the previous fstab is not the first one" do
        let(:selected_fstab) { fstab3 }

        it "does not disable button to 'select previous' fstab" do
          expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(:show_prev), :Enabled, false)

          subject.handle(event)
        end
      end
    end

    context "when 'show next' button is selected" do
      let(:selected_fstab) { fstab1 }

      let(:button) { :show_next }

      it "selects the next fstab" do
        subject.handle(event)

        expect(controller.selected_fstab).to eq(fstab2)
      end

      context "when the next fstab is the last one" do
        let(:selected_fstab) { fstab2 }

        # Mock #find_by_any_name that is called by SimpleEtcFstabEntry#find_device.
        # FIXME: that happens many times, which shows some caching is missing in the widget.
        before { allow(Y2Storage::BlkDevice).to receive(:find_by_any_name) }

        it "disables button to 'select next' fstab" do
          expect(Yast::UI).to receive(:ChangeWidget).with(Id(:show_next), :Enabled, false)

          subject.handle(event)
        end
      end

      context "when the next fstab is not the last one" do
        let(:selected_fstab) { fstab1 }

        it "does not disable button to 'select next' fstab" do
          expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(:show_next), :Enabled, false)

          subject.handle(event)
        end
      end
    end

    context "when 'help' button is selected" do
      let(:button) { :help }

      it "shows the help" do
        expect(Yast::Wizard).to receive(:ShowHelp).with(/has scanned/)

        subject.handle(event)
      end
    end
  end

  describe "#validate" do
    before do
      allow(Yast2::Popup).to receive(:show).and_return(accept)
      # See comment above about #find_by_any_name and SimpleEtcFstabEntry#find_device
      allow(Y2Storage::BlkDevice).to receive(:find_by_any_name)
    end

    let(:accept) { nil }

    context "when some mount point of the selected fstab cannot be imported" do
      let(:selected_fstab) { fstab3 }

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show)

        subject.validate
      end

      context "and the user accepts" do
        let(:accept) { :yes }

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end

      context "and the user does not accept" do
        let(:accept) { :no }

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end
    end

    context "when all mount points of the selected fstab can be imported" do
      let(:selected_fstab) { fstab1 }

      it "does not show an error" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.validate
      end

      it "returns true" do
        expect(subject.validate).to eq(true)
      end
    end
  end

  describe Y2Partitioner::Widgets::FstabSelector::FstabArea do
    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::FstabSelector::FstabContent do
    subject { described_class.new(selected_fstab) }

    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::FstabSelector::FstabTable do
    subject { described_class.new(selected_fstab) }

    include_examples "CWM::CustomWidget"
  end
end
