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

require_relative "../../../spec_helper.rb"
require "y2storage/dialogs/guided_setup"

describe Y2Storage::Dialogs::GuidedSetup::SelectFilesystem::VolumeWidget do
  # Convenience method to inspect the tree of terms for the UI
  def term_with_id(regexp, content)
    content.nested_find do |param|
      next unless param.is_a?(Yast::Term)
      param.params.any? { |i| i.is_a?(Yast::Term) && i.value == :id && regexp.match?(i.params.first) }
    end
  end

  # Value of a widget term
  def item_value(item)
    # The value of the term is actually the first param of its inner Id term
    id_term = item.params.find { |i| i.is_a?(Yast::Term) && i.value == :id }
    id_term.params.first
  end

  subject(:widget) { described_class.new(settings, index) }

  let(:settings) { double("ProposalSettings", lvm: lvm, volumes: volumes) }
  let(:lvm) { false }

  let(:volumes) do
    [
      root_vol,
      home_vol,
      Y2Storage::VolumeSpecification.new(vol_features.merge("mount_point" => "swap")),
      Y2Storage::VolumeSpecification.new(vol_features.merge("mount_point" => "/var/lib")),
      Y2Storage::VolumeSpecification.new(vol_features.merge("adjust_by_ram_configurable" => true))
    ]
  end
  let(:vol_features) { {} }

  let(:root_vol) do
    Y2Storage::VolumeSpecification.new(
      vol_features.merge("mount_point" => "/", "snapshots_configurable" => true)
    )
  end
  let(:home_vol) do
    Y2Storage::VolumeSpecification.new(
      vol_features.merge("mount_point" => "/home", "fs_type" => "ext4", "fs_types" => "ext3,ext4")
    )
  end

  describe "#content" do
    let(:proposed_checkbox) { term_with_id(/_proposed$/, widget.content) }
    let(:fs_type_combo) { term_with_id(/_fs_type$/, widget.content) }
    let(:snapshots_checkbox) { term_with_id(/_snapshots$/, widget.content) }
    let(:adjust_by_ram_checkbox) { term_with_id(/_adjust_by_ram$/, widget.content) }

    context "if the user can decide the filesystem type" do
      let(:index) { 1 }
      let(:items) { fs_type_combo.params.last }

      it "includes a combo box with all the volume types" do
        expect(fs_type_combo.value).to eq :ComboBox
        item_ids = items.map { |i| item_value(i) }
        expect(item_ids).to contain_exactly(:ext3, :ext4)
      end

      it "initializes the combo box with the default option" do
        chosen = items.find { |i| i.params.last == true }
        expect(item_value(chosen)).to eq :ext4
      end
    end

    context "if the user cannot decide the filesystem type" do
      let(:index) { 2 }

      it "does not include a combo box to select the filesystem type" do
        expect(fs_type_combo).to be_nil
      end
    end

    context "if the user can decide whether to enlarge by ram" do
      let(:index) { 4 }

      it "includes the corresponding check box" do
        expect(adjust_by_ram_checkbox.value).to eq :CheckBox
      end
    end

    context "if the user cannot decide whether to enlarge by ram" do
      let(:index) { 0 }

      it "does not include the corresponding check box" do
        expect(adjust_by_ram_checkbox).to be_nil
      end
    end

    context "installing without LVM" do
      let(:lvm) { false }

      context "if the volume is optional" do
        before { vol_features["proposed_configurable"] = true }

        context "if the volume is home" do
          let(:index) { 1 }

          it "includes a check box to enable it with the appropiate label" do
            expect(proposed_checkbox.value).to eq :CheckBox
            expect(proposed_checkbox.params[-2]).to include "Home"
            expect(proposed_checkbox.params[-2]).to include "Partition"
          end
        end

        context "if the volume is swap" do
          let(:index) { 2 }

          it "includes a check box to enable it with the appropiate label" do
            expect(proposed_checkbox.value).to eq :CheckBox
            expect(proposed_checkbox.params[-2]).to include "Swap"
            expect(proposed_checkbox.params[-2]).to include "Partition"
          end
        end

        context "if the volume has a mount point different to swap or /home" do
          let(:index) { 3 }

          it "includes a check box to enable it with the appropiate label" do
            expect(proposed_checkbox.value).to eq :CheckBox
            expect(proposed_checkbox.params[-2]).to include "/var/lib"
            expect(proposed_checkbox.params[-2]).to include "Partition"
          end
        end

        context "if the volume has no mount point" do
          let(:index) { 4 }

          it "includes a check box to enable it with the appropiate label" do
            expect(proposed_checkbox.value).to eq :CheckBox
            expect(proposed_checkbox.params[-2]).to include "Additional"
            expect(proposed_checkbox.params[-2]).to include "Partition"
          end
        end
      end

      context "if the volume is mandatory" do
        before { vol_features["proposed_configurable"] = false }

        let(:first_label) do
          widget.content.nested_find { |w| w.is_a?(Yast::Term) && w.value == :Label }
        end

        context "if the volume is root" do
          let(:index) { 0 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "Root"
            expect(first_label.params.first).to include "Partition"
          end
        end

        context "if the volume is /home" do
          let(:index) { 1 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "Home"
            expect(first_label.params.first).to include "Partition"
          end
        end

        context "if the volume is swap" do
          let(:index) { 2 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "Swap"
            expect(first_label.params.first).to include "Partition"
          end
        end

        context "if the volume has a mount point different to swap or /home" do
          let(:index) { 3 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "/var/lib"
            expect(first_label.params.first).to include "Partition"
          end
        end

        context "if the volume has no mount point" do
          let(:index) { 4 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "Additional"
            expect(first_label.params.first).to include "Partition"
          end
        end
      end
    end

    context "installing with LVM" do
      let(:lvm) { true }

      context "if the volume is optional" do
        before { vol_features["proposed_configurable"] = true }

        context "if the volume is home" do
          let(:index) { 1 }

          it "includes a check box to enable it with the appropiate label" do
            expect(proposed_checkbox.value).to eq :CheckBox
            expect(proposed_checkbox.params[-2]).to include "Home"
            expect(proposed_checkbox.params[-2]).to include "Volume"
          end
        end

        context "if the volume is swap" do
          let(:index) { 2 }

          it "includes a check box to enable it with the appropiate label" do
            expect(proposed_checkbox.value).to eq :CheckBox
            expect(proposed_checkbox.params[-2]).to include "Swap"
            expect(proposed_checkbox.params[-2]).to include "Volume"
          end
        end

        context "if the volume has a mount point different to swap or /home" do
          let(:index) { 3 }

          it "includes a check box with the appropiate label" do
            expect(proposed_checkbox.value).to eq :CheckBox
            expect(proposed_checkbox.params[-2]).to include "/var/lib"
            expect(proposed_checkbox.params[-2]).to include "Volume"
          end
        end

        context "if the volume has no mount point" do
          let(:index) { 4 }

          it "includes a check box to enable it with the appropiate label" do
            expect(proposed_checkbox.value).to eq :CheckBox
            expect(proposed_checkbox.params[-2]).to include "Additional"
            expect(proposed_checkbox.params[-2]).to include "Volume"
          end
        end
      end

      context "if the volume is mandatory" do
        before { vol_features["proposed_configurable"] = false }

        let(:first_label) do
          widget.content.nested_find { |w| w.is_a?(Yast::Term) && w.value == :Label }
        end

        context "if the volume is root" do
          let(:index) { 0 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "Root"
            expect(first_label.params.first).to include "Volume"
          end
        end

        context "if the volume is /home" do
          let(:index) { 1 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "Home"
            expect(first_label.params.first).to include "Volume"
          end
        end

        context "if the volume is swap" do
          let(:index) { 2 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "Swap"
            expect(first_label.params.first).to include "Volume"
          end
        end

        context "if the volume has a mount point different to swap or /home" do
          let(:index) { 3 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "/var/lib"
            expect(first_label.params.first).to include "Volume"
          end
        end

        context "if the volume has no mount point" do
          let(:index) { 4 }

          it "does not include a check box to enable or disable it" do
            expect(proposed_checkbox).to eq nil
          end

          it "includes the appropiate label" do
            expect(first_label.params.first).to include "Additional"
            expect(first_label.params.first).to include "Volume"
          end
        end
      end
    end
  end

  describe "#store" do
    let(:index) { 0 }
    let(:volume) { volumes[index] }
    let(:vol_features) do
      {
        "proposed"                   => false,
        "proposed_configurable"      => true,
        "fs_type"                    => :ext3,
        "fs_types"                   => "btrfs,ext3,ext4",
        "snapshots"                  => false,
        "snapshots_configurable"     => true,
        "adjust_by_ram"              => true,
        "adjust_by_ram_configurable" => true
      }
    end

    before do
      allow(Yast::UI).to receive(:QueryWidget) do |id, _attr|
        case id.params.first
        when /_proposed/
          true
        when /_fs_type/
          :btrfs
        when /_snapshots/
          true
        when /_adjust_by_ram/
          false
        end
      end
    end

    it "updates #proposed for the volume" do
      widget.store
      expect(volume.proposed).to eq true
    end

    it "updates #fs_type for the volume" do
      widget.store
      expect(volume.fs_type).to eq Y2Storage::Filesystems::Type::BTRFS
    end

    it "updates #snapshots for the volume" do
      widget.store
      expect(volume.snapshots).to eq true
    end

    it "updates #adjust_by_ram for the volume" do
      widget.store
      expect(volume.adjust_by_ram).to eq false
    end
  end

  describe "#handle" do
    let(:index) { 0 }
    let(:volume) { volumes[index] }
    let(:vol_features) { { "proposed_configurable" => true, "adjust_by_ram_configurable" => true } }

    before do
      allow(Yast::UI).to receive(:QueryWidget)
      allow(Yast::UI).to receive(:ChangeWidget)
    end

    context "when the user enables the volume" do
      let(:widget_id) { "vol_#{index}_proposed" }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(widget_id), :Value).and_return true
      end

      it "enables the file system type combo, if any" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id("vol_0_fs_type"), :Enabled, true)
        widget.handle(widget_id)
      end

      it "enables the snapshots check box, if needed" do
        allow(Yast::UI).to receive(:QueryWidget).with(Id("vol_0_fs_type"), :Value).and_return :btrfs
        expect(Yast::UI).to receive(:ChangeWidget).with(Id("vol_0_snapshots"), :Enabled, true)
        widget.handle(widget_id)
      end

      it "enables the adjust by ram check box, if any" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id("vol_0_adjust_by_ram"), :Enabled, true)
        widget.handle(widget_id)
      end
    end

    context "when the user disables the volume" do
      let(:widget_id) { "vol_#{index}_proposed" }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(widget_id), :Value).and_return false
      end

      it "disables the file system type combo, if any" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id("vol_0_fs_type"), :Enabled, false)
        widget.handle(widget_id)
      end

      it "disables the snapshots check box, if any" do
        allow(Yast::UI).to receive(:QueryWidget).with(Id("vol_0_fs_type"), :Value).and_return :btrfs
        expect(Yast::UI).to receive(:ChangeWidget).with(Id("vol_0_snapshots"), :Enabled, false)
        widget.handle(widget_id)
      end

      it "disables the adjust by ram check box, if any" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id("vol_0_adjust_by_ram"), :Enabled, false)
        widget.handle(widget_id)
      end
    end

    context "when the user selects the Btrfs file system type" do
      let(:widget_id) { "vol_#{index}_fs_type" }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(widget_id), :Value).and_return :btrfs
        allow(Yast::UI).to receive(:QueryWidget).with(Id("vol_0_proposed"), :Value).and_return true
      end

      context "if snapshots are configurable" do
        let(:index) { 0 }

        it "enables the snapshots check box" do
          expect(Yast::UI).to receive(:ChangeWidget).with(Id("vol_0_snapshots"), :Enabled, true)
          widget.handle(widget_id)
        end
      end

      context "if snapshots are not configurable" do
        let(:index) { 1 }

        it "does not try to enable or disable any other widget" do
          expect(Yast::UI).to_not receive(:ChangeWidget)
          widget.handle(widget_id)
        end
      end
    end

    context "when the user selects a non-Btrfs file system type" do
      let(:widget_id) { "vol_#{index}_fs_type" }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(widget_id), :Value).and_return :ext3
        allow(Yast::UI).to receive(:QueryWidget).with(Id("vol_0_proposed"), :Value).and_return true
      end

      context "if snapshots are configurable" do
        let(:index) { 0 }

        it "disables the snapshots check box" do
          expect(Yast::UI).to receive(:ChangeWidget).with(Id("vol_0_snapshots"), :Enabled, false)
          widget.handle(widget_id)
        end
      end

      context "if snapshots are not configurable" do
        let(:index) { 1 }

        it "does not try to enable or disable any other widget" do
          expect(Yast::UI).to_not receive(:ChangeWidget)
          widget.handle(widget_id)
        end
      end
    end
  end
end
