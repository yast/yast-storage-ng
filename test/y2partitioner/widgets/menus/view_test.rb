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
require "y2partitioner/widgets/menus/view"

describe Y2Partitioner::Widgets::Menus::View do
  subject(:menu) { described_class.new }
  let(:device_graph_supported) { true }

  def entry_id(entry)
    id_term = entry.params.find { |param| param.is_a?(Yast::Term) && param.value.to_sym == :id }
    return nil unless id_term

    id_term.params.first
  end

  before do
    allow(Y2Partitioner::Dialogs::DeviceGraph).to receive(:supported?)
      .and_return(device_graph_supported)
  end

  describe "#items" do
    shared_examples "common menu entries" do
      it "contains an entry for the installation summary" do
        entry = menu.items.find { |e| entry_id(e) == :installation_summary }
        expect(entry).to_not be_nil
      end

      it "contains an entry for settings" do
        entry = menu.items.find { |e| entry_id(e) == :settings }
        expect(entry).to_not be_nil
      end

      it "contains an entry for the Bcache csets" do
        entry = menu.items.find { |e| entry_id(e) == :bcache_csets }
        expect(entry).to_not be_nil
      end
    end

    context "when device grahp dialog is supported" do
      include_examples "common menu entries"

      it "contains an entry for the device graph" do
        entry = menu.items.find { |e| entry_id(e) == :device_graphs }
        expect(entry).to_not be_nil
      end
    end

    context "when device grahp dialog is not supported" do
      let(:device_graph_supported) { false }

      include_examples "common menu entries"

      it "does not contain an entry for the device graph" do
        entry = menu.items.find { |e| entry_id(e) == :device_graphs }
        expect(entry).to be_nil
      end
    end
  end

  describe "#handle" do
    context "when user wants to see the device graph" do
      let(:event) { :device_graphs }

      it "opens the DeviceGraph dialog" do
        expect(Y2Partitioner::Dialogs::DeviceGraph).to receive(:new)

        menu.handle(event)
      end
    end

    context "when user wants to see the summary" do
      let(:event) { :installation_summary }

      it "opens the summary dialog" do
        expect(Y2Partitioner::Dialogs::SummaryPopup).to receive(:new)

        menu.handle(event)
      end
    end

    context "when user wants to see the settings" do
      let(:event) { :settings }

      it "opens the settings dialog" do
        expect(Y2Partitioner::Dialogs::Settings).to receive(:new)

        menu.handle(event)
      end
    end

    context "when user wants to see the bcache csets" do
      let(:event) { :bcache_csets }

      it "opens the settings dialog" do
        expect(Y2Partitioner::Dialogs::BcacheCsets).to receive(:new)

        menu.handle(event)
      end
    end
  end
end
