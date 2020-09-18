#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/menus/system"
require "y2partitioner/widgets/menus/configure"

describe Y2Partitioner::Widgets::Menus::System do
  subject(:menu) { described_class.new }

  let(:available_submenus) do
    menu.items.select { |i| i.is_a?(Yast::Term) && i.value == :menu }.map do |entry|
      Yast::String.RemoveShortcut(entry.params.first)
    end
  end

  let(:items) do
    menu.items.select { |i| i.is_a?(Yast::Term) && i.value == :item }
  end

  let(:items_ids) do
    items.flat_map(&:params).select { |p| p.is_a?(Yast::Term) && p.value == :id }.flat_map(&:params)
  end

  def entry_id(entry)
    id_term = entry.params.find { |param| param.is_a?(Yast::Term) && param.value.to_sym == :id }
    return nil unless id_term

    id_term.params.first
  end

  def submenu_label(entry)
    return nil unless entry.is_a?(Yast::Term) && entry.value.to_sym == :menu

    Yast::String.RemoveShortcut(entry.params.first)
  end

  describe "#items" do
    shared_examples "common menu entries" do
      it "contains an entry for rescanning devices" do
        entry = menu.items.find { |e| entry_id(e) == :rescan_devices }
        expect(entry).to_not be_nil
      end

      it "contains an entry for discarding changes" do
        entry = menu.items.find { |e| entry_id(e) == :abort }
        expect(entry).to_not be_nil
      end

      it "contains an entry for saving changes" do
        entry = menu.items.find { |e| entry_id(e) == :next }
        expect(entry).to_not be_nil
      end

      it "contains the 'Configure' submenu" do
        entry = menu.items.find { |e| submenu_label(e) == "Configure" }
        expect(entry).to_not be_nil
      end
    end

    context "during installation" do
      before do
        allow(Yast::Stage).to receive(:initial).and_return true
      end

      include_examples "common menu entries"

      it "contains an entry for importing mount points" do
        entry = menu.items.find { |e| entry_id(e) == :import_mount_points }
        expect(entry).to_not be_nil
      end
    end

    context "in an already installed system" do
      before do
        allow(Yast::Stage).to receive(:initial).and_return false
      end

      include_examples "common menu entries"

      it "does not contain an entry for importing mount points" do
        entry = menu.items.find { |e| entry_id(e) == :import_mount_points }
        expect(entry).to be_nil
      end
    end
  end

  describe "#handle" do
    let(:event) { :whatever }
    let(:configure_menu) { double(Y2Partitioner::Widgets::Menus::Configure) }

    before do
      allow(configure_menu).to receive(:handle)
      allow(Y2Partitioner::Widgets::Menus::Configure).to receive(:new).and_return(configure_menu)
    end

    it "delegates event to configure menu" do
      expect(configure_menu).to receive(:handle).with(event)

      menu.handle(event)
    end

    context "when rescaning devices" do
      let(:event) { :rescan_devices }

      it "triggers the RescanDevices action" do
        expect(Y2Partitioner::Actions::RescanDevices).to receive(:new)

        menu.handle(event)
      end
    end

    context "when importing mount points" do
      let(:event) { :import_mount_points }

      it "triggers the ImportMountPoints action" do
        expect(Y2Partitioner::Actions::ImportMountPoints).to receive(:new)

        menu.handle(event)
      end
    end
  end
end
