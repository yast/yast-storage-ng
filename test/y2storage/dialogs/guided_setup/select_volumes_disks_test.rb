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

require_relative "../../spec_helper.rb"
require_relative "#{TEST_PATH}/support/guided_setup_context"

describe Y2Storage::Dialogs::GuidedSetup::SelectVolumesDisks do
  include_context "guided setup requirements"

  subject { described_class.new(guided_setup) }

  let(:all_disks) { ["/dev/sda", "/dev/sdb"] }

  let(:propose_separated_swap) { false }
  let(:propose_separated_home) { false }

  let(:volumes_sets) do
    [instance_double("VolumeSpecificationsSet", proposed?: true),
     instance_double("VolumeSpecificationsSet", proposed?: propose_separated_swap),
     instance_double("VolumeSpecificationsSet", proposed?: propose_separated_home)]
  end

  before do
    allow(settings).to receive(:volumes_sets).and_return(volumes_sets)
  end

  describe "#skip?" do
    context "when there is only one candidate disk" do
      let(:all_disks) { ["/dev/sda"] }

      it "returns true" do
        expect(subject.skip?).to be(true)
      end
    end

    context "when there are several candidate disks" do
      let(:all_disks) { ["/dev/sda", "/dev/sdb"] }

      it "returns false" do
        expect(subject.skip?).to be(false)
      end
    end
  end

  describe "#run" do
    context "when only one volume set is proposed to be created separately" do
      it "displays only one disk selector" do
        expect(Y2Storage::Dialogs::GuidedSetup::Widgets::DiskSelector).to receive(:new).once

        subject.run
      end
    end

    context "when more than one volume set is proposed to be created separately" do
      let(:propose_separated_home) { true }

      it "displays a disk selector for each one" do
        expect(Y2Storage::Dialogs::GuidedSetup::Widgets::DiskSelector).to receive(:new).twice

        subject.run
      end
    end
  end

  describe "#next_handler" do
    let(:propose_separated_home) { true }

    let(:system_disk_selector) do
      instance_double(Y2Storage::Dialogs::GuidedSetup::Widgets::DiskSelector, store: true)
    end

    let(:home_disk_selector) do
      instance_double(Y2Storage::Dialogs::GuidedSetup::Widgets::DiskSelector, store: true)
    end

    before do
      allow(Y2Storage::Dialogs::GuidedSetup::Widgets::DiskSelector)
        .to receive(:new)
        .with(0, any_args)
        .and_return(system_disk_selector)

      allow(Y2Storage::Dialogs::GuidedSetup::Widgets::DiskSelector)
        .to receive(:new)
        .with(2, any_args)
        .and_return(home_disk_selector)
    end

    it "stores all widgets" do
      expect(system_disk_selector).to receive(:store)
      expect(home_disk_selector).to receive(:store)

      subject.next_handler
    end
  end
end
