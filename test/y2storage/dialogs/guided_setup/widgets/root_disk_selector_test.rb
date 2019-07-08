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

require_relative "../../../spec_helper.rb"
require_relative "#{TEST_PATH}/support/widgets_context"
require "y2storage/dialogs/guided_setup/widgets/root_disk_selector"

describe Y2Storage::Dialogs::GuidedSetup::Widgets::RootDiskSelector do
  include_context "widgets"

  before do
    fake_scenario(scenario)
    allow(settings).to receive(:allocate_volume_mode).and_return(:auto)
  end

  subject { described_class.new(widget_id, settings, candidate_disks: candidate_disks) }

  let(:widget_id) { "root_disk_selector" }

  let(:settings) { Y2Storage::ProposalSettings.new }

  let(:candidate_disks) { [] }

  let(:scenario) { "empty_disks" }

  let(:sda) { fake_devicegraph.find_by_name("/dev/sda") }

  let(:sdb) { fake_devicegraph.find_by_name("/dev/sdb") }

  describe "#content" do
    context "when there is only one candidate disk" do
      let(:candidate_disks) { [sda] }

      it "does not allow to select a candidate disk" do
        widget = find_widget(widget_id, subject.content)

        expect(widget).to be_nil
      end

      it "contains a label with the name of the candidate disk" do
        widget = subject.content.nested_find do |w|
          w.is_a?(Yast::Term) && w.value == :Label && w.params.first == "/dev/sda"
        end

        expect(widget).to_not be_nil
      end
    end

    context "when there are several candidate disks" do
      let(:candidate_disks) { [sda, sdb] }

      it "allows to select a candidate disk" do
        widget = find_widget(widget_id, subject.content)

        expect(widget).to_not be_nil
      end

      it "contains an option to select any disk" do
        widget = find_widget(:any_disk, subject.content)

        expect(widget).to_not be_nil
      end

      it "contains an option to select each candidate disk" do
        sda_widget = find_widget("/dev/sda", subject.content)
        sdb_widget = find_widget("/dev/sdb", subject.content)

        expect(sda_widget).to_not be_nil
        expect(sdb_widget).to_not be_nil
      end
    end
  end

  describe "#init" do
    context "when the settings has a root device" do
      before do
        settings.root_device = "/dev/sda"
      end

      it "selects the root device" do
        expect_select("/dev/sda")

        subject.init
      end
    end

    context "when the settings has no root device" do
      before do
        settings.root_device = nil
      end

      it "selects the 'any disk' option" do
        expect_select(:any_disk)

        subject.init
      end
    end
  end

  describe "#store" do
    context "when there is only one candidate disk" do
      let(:candidate_disks) { [sda] }

      it "updates the settings with root_device as the candidate disk" do
        subject.store

        expect(settings.root_device).to eq("/dev/sda")
      end
    end

    context "when there are several candidate disks" do
      let(:candidate_disks) { [sda, sdb] }

      context "and 'any disk' option is selected" do
        before do
          select_widget(:any_disk)
        end

        it "updates settings with root_device to nil" do
          subject.store

          expect(settings.root_device).to be_nil
        end
      end

      context "and a disk option is selected" do
        before do
          select_widget("/dev/sdb")
        end

        it "updates settings with root_device as the selected disk" do
          subject.store

          expect(settings.root_device).to eq("/dev/sdb")
        end
      end
    end
  end

  describe "#value" do
    context "when there is only one candidate disk" do
      let(:candidate_disks) { [sda] }

      it "returns the name of the candidate disk" do
        expect(subject.value).to eq("/dev/sda")
      end
    end

    context "when there are several candidate disks" do
      let(:candidate_disks) { [sda, sdb] }

      context "and 'any disk' option is selected" do
        before do
          select_widget(:any_disk)
        end

        it "returns nil" do
          expect(subject.value).to be_nil
        end
      end

      context "and a disk option is selected" do
        before do
          select_widget("/dev/sda")
        end

        it "returns the name of the selected disk" do
          expect(subject.value).to eq("/dev/sda")
        end
      end
    end
  end

  describe "#value=" do
    context "when there is only one candidate disk" do
      let(:candidate_disks) { [sda] }

      it "does not select any option" do
        expect(Yast::UI).to_not receive(:ChangeWidget)

        subject.value = "/dev/sdc"
      end
    end

    context "when there are several candidate disks" do
      let(:candidate_disks) { [sda, sdb] }

      it "selects the givem option" do
        expect_select("/dev/sda")

        subject.value = "/dev/sda"
      end
    end
  end

  describe "#help" do
    it "returns the help text" do
      expect(subject.help).to match(/Select the disk/)
    end
  end
end
