#!/usr/bin/env rspec
#
# Copyright (c) [2019] SUSE LLC
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
require "y2storage/dialogs/guided_setup/widgets/disk_selector"

describe Y2Storage::Dialogs::GuidedSetup::Widgets::DiskSelector do
  include_context "widgets"

  subject(:widget) { described_class.new(index, settings, candidate_disks: candidate_disks) }

  let(:disk1) { instance_double(Y2Storage::Disk, name: "/dev/disk1", size: "100GiB") }
  let(:disk2) { instance_double(Y2Storage::Disk, name: "/dev/disk2", size: "200GiB") }

  let(:candidate_disks) { [disk1, disk2] }

  let(:lvm) { false }

  let(:separate_vgs) { false }

  let(:vol_features) { {} }

  let(:volumes) do
    [
      Y2Storage::VolumeSpecification.new(vol_features.merge("mount_point" => "/")),
      Y2Storage::VolumeSpecification.new(vol_features.merge("mount_point" => "swap")),
      home_vol,
      spacewalk_vol
    ]
  end

  let(:home_vol) do
    Y2Storage::VolumeSpecification.new(
      vol_features.merge(
        "mount_point"      => "/home",
        "fs_type"          => "ext4",
        "fs_types"         => "ext3,ext4",
        "separate_vg_name" => "vg-home"
      )
    )
  end

  let(:spacewalk_vol) do
    Y2Storage::VolumeSpecification.new(
      vol_features.merge(
        "mount_point"      => "/var/lib/spacewalk",
        "separate_vg_name" => "vg-spacewalk"
      )
    )
  end

  let(:settings) { Y2Storage::ProposalSettings.new_for_current_product }

  describe "#content" do
    let(:index) { 0 }

    let(:label) { find_widget(/label_of_/, widget.content) }
    let(:selector) { find_widget(/^disk_for_/, widget.content) }
    let(:selector_items) { selector.params[2] }

    before do
      allow(settings).to receive(:volumes).and_return(volumes)
      allow(settings).to receive(:lvm).and_return(lvm)
      allow(settings).to receive(:separate_vgs).and_return(separate_vgs)
    end

    it "contains an item per candidate disk" do
      expect(selector_items.count).to eq(2)
    end

    context "installing without LVM" do
      context "and not proposing separated vgs" do
        it "includes the label for partition" do
          expect(label.params[1]).to include("Partition")
        end
      end

      context "but proposing separated vgs" do
        let(:separate_vgs) { true }

        context "when given a :separate_lvm volume specification set" do
          let(:index) do
            settings.volumes_sets.find_index { |vs| vs.type == :separate_lvm }
          end

          it "includes the label for volume group" do
            expect(label.params[1]).to include("Volume Group")
          end
        end

        context "when given a :partition volume specification set" do
          let(:index) do
            settings.volumes_sets.find_index { |vs| vs.type == :partition }
          end

          it "includes the label for partition" do
            expect(label.params[1]).to include("Partition")
          end
        end
      end
    end

    context "installing with LVM" do
      let(:lvm) { true }

      context "and not proposing separated vgs" do
        it "includes the label for system LVM" do
          expect(label.params[1]).to include("system LVM")
        end
      end

      context "but proposing separated vgs" do
        let(:separate_vgs) { true }

        context "when given a :separate_lvm volume specification set" do
          let(:index) do
            settings.volumes_sets.find_index { |vs| vs.type == :separate_lvm }
          end

          it "includes the label for volume group" do
            expect(label.params[1]).to include("Volume Group")
          end
        end

        context "when given a :lvm volume specification set" do
          let(:index) do
            settings.volumes_sets.find_index { |vs| vs.type == :lvm }
          end

          it "includes the label for system LVM" do
            expect(label.params[1]).to include("system LVM")
          end
        end
      end
    end
  end
end
