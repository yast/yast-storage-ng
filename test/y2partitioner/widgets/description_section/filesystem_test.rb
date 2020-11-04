#!/usr/bin/env rspec

# Copyright (c) [2019-2020] SUSE LLC
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

require_relative "../../test_helper"
require_relative "help_fields_examples"

require "y2partitioner/widgets/description_section/filesystem"

describe Y2Partitioner::Widgets::DescriptionSection::Filesystem do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(filesystem) }

  let(:filesystem) { device.filesystem }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks" }

  let(:device_name) { "/dev/sda2" }

  describe "#value" do
    it "includes a section title" do
      expect(subject.value).to match(/<h3>.*<\/h3>/)
    end

    it "includes a list of entries" do
      expect(subject.value).to match(/<ul>.*<\/ul>/)
    end

    it "includes an entry about the filesystem type" do
      expect(subject.value).to match(/Type:/)
    end

    it "includes an entry about the mount point" do
      expect(subject.value).to match(/Mount Point:/)
    end

    it "includes an entry about the mount by" do
      expect(subject.value).to match(/Mount By:/)
    end

    it "includes an entry about the filesystem label" do
      expect(subject.value).to match(/Label:/)
    end

    it "includes an entry about the filesystem UUID" do
      expect(subject.value).to match(/UUID:/)
    end

    it "does not include an entry about the metadata raid level" do
      expect(subject.value).to_not match(/Metadata RAID Level:/)
    end

    it "does not include an entry about the data raid level" do
      expect(subject.value).to_not match(/RAID Level:/)
    end

    it "contains (not mounted) if mount point is not active" do
      allow(filesystem).to receive(:mount_point)
        .and_return(double(path: "/", active?: false).as_null_object)

      expect(subject.value).to match(/Mount Point: \/ \(not mounted\)/)
    end

    context "when using a Ext3/4 filesystem" do
      context "with an external journal" do
        let(:scenario) { "bug_1145841.xml" }

        let(:device_name) { "/dev/BACKUP_R6/BACKUP_R6" }

        it "includes an entry about the journal device" do
          expect(subject.value).to match(/Journal Device:/)
        end

        it "shows the device used to hold the journal" do
          expect(subject.value).to match(/\/dev\/sdd1/)
        end
      end

      context "without an external journal" do
        let(:device_name) { "/dev/sda2" }

        it "includes an empty entry about the journal device" do
          expect(subject.value).to_not match(/Journal Device:$/)
        end
      end
    end

    context "when using a no Ext3/4 filesystem" do
      let(:device_name) { "/dev/sdb5" }

      it "does not include an entry about the journal" do
        expect(subject.value).to_not match(/Journal Device:/)
      end
    end

    context "when using a Btrfs filesystem" do
      let(:scenario) { "btrfs_on_disk" }

      let(:device_name) { "/dev/sda" }

      it "includes an entry about the metadata raid level" do
        expect(subject.value).to match(/Metadata RAID Level:/)
      end

      it "includes an entry about the data raid level" do
        expect(subject.value).to match(/RAID Level:/)
      end

      it "includes an entry about the used devices" do
        expect(subject.value).to match(/Used Devices:/)
      end
    end
  end

  describe "#help_fields" do
    let(:excluded_help_fields) { [] }

    include_examples "help fields"
  end
end
