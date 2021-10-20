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
require "y2storage/dialogs/guided_setup/helpers/disk"

describe Y2Storage::Dialogs::GuidedSetup::Helpers::Disk do
  using Y2Storage::Refinements::SizeCasts

  subject { described_class.new(analyzer) }

  let(:analyzer) { instance_double(Y2Storage::DiskAnalyzer) }

  describe "#label" do
    before do
      allow(disk).to receive(:name).and_return(name)
      allow(disk).to receive(:size).and_return(20.GiB)
      allow(disk).to receive(:respond_to?).with(anything)
      allow(disk).to receive(:respond_to?).with(:transport).and_return(true)
      allow(disk).to receive(:transport).and_return(transport)
      allow(disk).to receive(:is?).with(:sd_card).and_return(sd_card)
      allow(disk).to receive(:boss?).and_return(boss)

      allow(transport).to receive(:is?).with(:usb).and_return(usb)
      allow(transport).to receive(:is?).with(:sbp).and_return(sbp)

      allow(analyzer).to receive(:installed_systems).with(disk).and_return(installed_systems)
    end

    let(:disk) { instance_double(Y2Storage::Disk) }

    let(:transport) { instance_double(Y2Storage::DataTransport) }

    let(:name) { "/dev/sda" }
    let(:usb) { false }
    let(:sbp) { false }
    let(:sd_card) { false }
    let(:boss) { false }
    let(:installed_systems) { [] }

    it "contains the disk name and the size" do
      expect(subject.label(disk)).to match(/\/dev\/sda, 20.00 GiB/)
    end

    context "when the disk is a MMC/SDCard" do
      let(:sd_card) { true }

      it "includes the 'SD Card' label" do
        expect(subject.label(disk)).to match(/SD Card/)
      end
    end

    context "when the disk is a Dell BOSS drive" do
      let(:boss) { true }

      it "includes the 'Dell BOSS' label" do
        expect(subject.label(disk)).to match(/Dell BOSS/)
      end
    end

    context "when the disk transport is usb" do
      let(:usb) { true }

      it "includes the 'USB' label" do
        expect(subject.label(disk)).to match(/USB/)
      end
    end

    context "when the disk transport is sbp" do
      let(:sbp) { true }

      it "includes the 'IEEE 1394' label" do
        expect(subject.label(disk)).to match(/IEEE 1394/)
      end
    end

    context "when the disk contains installed systems" do
      let(:installed_systems) { ["Windows", "Linux"] }

      it "includes the installed systems" do
        expect(subject.label(disk)).to match(/Windows, Linux/)
      end
    end
  end
end
