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

require_relative "../../support/guided_setup_context"

describe Y2Storage::Dialogs::GuidedSetup::SelectRootDisk do
  include_context "guided setup requirements"

  subject { described_class.new(guided_setup) }

  let(:all_disks) { ["/dev/sda", "/dev/sdb"] }

  let(:candidate_disks) { all_disks }

  before do
    settings.candidate_devices = candidate_disks
  end

  describe "#run" do
    context "when settings has not a root disk" do
      before { settings.root_device = nil }

      it "selects 'any' option by default" do
        expect_select(:any)
        expect_not_select("/dev/sda")
        expect_not_select("/dev/sdb")
        subject.run
      end
    end

    context "when settings has a root disk" do
      before { settings.root_device = "/dev/sda" }

      it "selects that disks by default" do
        expect_select("/dev/sda")
        expect_not_select("/dev/sdb")
        subject.run
      end
    end

    context "when there is only one disk" do
      let(:all_disks) { ["/dev/sda"] }

      it "updates settings with that disk" do
        subject.run
        expect(subject.settings.root_device).to eq("/dev/sda")
      end
    end

    context "when there are several disks" do
      context "and a disk is selected" do
        before { select_disks(["/dev/sdb"]) }

        it "updates settings with the selected disk" do
          subject.run
          expect(subject.settings.root_device).to eq("/dev/sdb")
        end
      end

      context "and 'any' option is selected" do
        before { select_disks([:any]) }

        it "updates settings with root disk as nil" do
          subject.run
          expect(subject.settings.root_device).to be_nil
        end
      end
    end

    context "when the selected disk has not installed Windows" do
      before { select_disks(["/dev/sda"]) }

      let(:windows_systems) { [] }

      it "disables windows actions" do
        expect_disable(:windows_action)
        subject.run
      end
    end

    context "when the selected disk has installed Windows" do
      before { select_disks(["/dev/sda"]) }

      let(:windows_systems) { ["Windows"] }

      it "enables windows actions" do
        expect_enable(:windows_action)
        subject.run
      end
    end

    context "when the selected disk has not installed Linux" do
      before { select_disks(["/dev/sda"]) }

      let(:linux_systems) { [] }

      it "disables linux actions" do
        expect_disable(:linux_action)
        subject.run
      end
    end

    context "when the selected disk has installed Linux" do
      before { select_disks(["/dev/sda"]) }

      let(:linux_systems) { ["openSUSE"] }

      it "enables linux actions" do
        expect_enable(:linux_action)
        subject.run
      end
    end

    context "when settings has action for Windows systems" do
      it "selects that action by default" do
        skip "no settings exists for that"
      end
    end

    context "when settings has action for Linux partitions" do
      it "selects that action by default" do
        skip "no settings exists for that"
      end
    end

    context "when an action is selected for Windows systems" do
      it "updates settings with the selected action for Windows systems" do
        skip "no settings exists for that"
      end
    end

    context "when an action is selected for Linux partitions" do
      it "updates settings with the selected action for Linux partitions" do
        skip "no settings exists for that"
      end
    end
  end
end
