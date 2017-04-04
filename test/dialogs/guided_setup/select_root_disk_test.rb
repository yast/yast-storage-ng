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

  let(:disks_data) do
    [
      { name: "/dev/sda", label: "" },
      { name: "/dev/sdb", label: "" }
    ]
  end

  let(:candidate_disks) { all_disks }

  before do
    settings.candidate_devices = candidate_disks
  end

  describe "#run" do
    it "selects the first candidate as root disk by default" do
      expect_select("/dev/sda")
      expect_not_select("/dev/sdb")
      subject.run
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

    it "updates settings with the selected disk" do
      select_disks(["/dev/sdb"])
      subject.run
      expect(subject.settings.root_device).to eq("/dev/sdb")
    end

    it "updates settings with the selected action for Windows systems" do
      skip "no settings exists for that"
    end

    it "updates settings with the selected action for Linux partitions" do
      skip "no settings exists for that"
    end
  end
end
