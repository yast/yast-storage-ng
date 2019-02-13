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
# find current contact information at www.suse.com.

require_relative "../../spec_helper.rb"
require_relative "#{TEST_PATH}/support/guided_setup_context"

describe Y2Storage::Dialogs::GuidedSetup::SelectDisks do
  include_context "guided setup requirements"

  subject { described_class.new(guided_setup) }

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
    before do
      settings.candidate_devices = candidate_disks
      select_disks(selected_disks)
    end

    let(:all_disks) { ["/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd"] }

    context "when settings has not candidate disks" do
      let(:candidate_disks) { [] }

      it "selects 3 first disks by default" do
        expect_select("/dev/sda")
        expect_select("/dev/sdb")
        expect_select("/dev/sdc")
        expect_not_select("/dev/sdd")
        subject.run
      end
    end

    context "when settings has some candidate disks" do
      let(:candidate_disks) { ["/dev/sda", "/dev/sdb", "/dev/sdd", "/dev/sdc"] }

      it "selects 3 first candidates by default" do
        expect_select("/dev/sda")
        expect_select("/dev/sdb")
        expect_select("/dev/sdd")
        expect_not_select("/dev/sdc")
        subject.run
      end
    end

    context "when there are not selected disks" do
      let(:candidate_disks) { all_disks }
      let(:selected_disks) { [] }

      it "shows an error message" do
        expect(Yast::Report).to receive(:Warning)
        subject.run
      end

      it "does not save settings" do
        expect(settings.candidate_devices).to eq(candidate_disks)
        subject.run
      end
    end

    context "when there are more than 3 selected disks" do
      let(:candidate_disks) { all_disks }
      let(:selected_disks) { ["/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd"] }

      it "shows an error message" do
        expect(Yast::Report).to receive(:Warning)
        subject.run
      end

      it "does not save settings" do
        expect(settings.candidate_devices).to eq(candidate_disks)
        subject.run
      end
    end

    context "when there are between 1 and 3 selected disks" do
      let(:candidate_disks) { all_disks }
      let(:selected_disks) { ["/dev/sda", "/dev/sdc"] }

      it "does not show an error message" do
        expect(Yast::Report).not_to receive(:Warning)
        subject.run
      end

      it "updates the settings" do
        subject.run
        expect(subject.settings.candidate_devices).to eq(selected_disks)
      end
    end

    describe "dialog content" do
      using Y2Storage::Refinements::SizeCasts

      let(:usb) { Y2Storage::DataTransport::USB }
      let(:sbp) { Y2Storage::DataTransport::SBP }
      let(:ata) { Y2Storage::DataTransport::ATA }

      before { allow(analyzer).to receive(:candidate_disks).and_return(disks) }

      let(:content) { subject.send(:dialog_content) }

      let(:first_disks) do
        [
          double("Disk", name: "/dev/sda", size: 10.GiB, transport: usb),
          double("Disk", name: "/dev/sdb", size: 20.GiB, transport: sbp),
          double("Disk", name: "/dev/sdc", size: 30.GiB, transport: ata),
          double("Disk", name: "/dev/sdd", size: 40.GiB)
        ]
      end

      RSpec.shared_examples "disk descriptions" do
        it "includes the transport in the description of USB and SBP devices" do
          sda_desc = disk_descriptions.find { |i| i.start_with?("/dev/sda") }
          sdb_desc = disk_descriptions.find { |i| i.start_with?("/dev/sdb") }
          expect(sda_desc).to match(/10.00 GiB, USB/)
          expect(sdb_desc).to match(/20.00 GiB, IEEE 1394/)
        end

        it "does not include the transport for regular disks" do
          sdc_desc = disk_descriptions.find { |i| i.start_with?("/dev/sdc") }
          sdd_desc = disk_descriptions.find { |i| i.start_with?("/dev/sdd") }
          expect(sdc_desc).to match(/30.00 GiB$/)
          expect(sdd_desc).to match(/40.00 GiB$/)
        end
      end

      context "with 10 or less candidate devices" do
        let(:disks) { first_disks }
        let(:disk_descriptions) { disks.map { |d| term_with_id(d.name, content).params.last } }

        include_examples "disk descriptions"
      end

      context "with more than 10 candidate devices" do
        let(:disks) do
          first_disks + [
            disk("/dev/sde"), disk("/dev/sdf"), disk("/dev/sdg"), disk("/dev/sdh"),
            disk("/dev/sdi"), disk("/dev/sdj"), disk("/dev/sdk"), disk("/dev/sdl")
          ]
        end

        let(:disk_descriptions) do
          multi_select = content.nested_find do |nested|
            nested.is_a?(Yast::Term) && nested.params.last.is_a?(Array)
          end
          multi_select.params.last.map { |i| i.params.last }
        end

        include_examples "disk descriptions"
      end
    end
  end
end
