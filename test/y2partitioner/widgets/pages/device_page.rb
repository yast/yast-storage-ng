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

RSpec.shared_examples "device page" do |overview_tab_id, devices_tab_id|
  let(:tabs_widget) do
    subject.contents.nested_find { |e| e.is_a?(CWM::PushButtonTabPager) }
  end

  let(:overview_tab) { tabs_widget.send(:page_for_id, overview_tab_id) }
  let(:devices_tab) { tabs_widget.send(:page_for_id, devices_tab_id) }
  let(:ui_state) { Y2Partitioner::UIState.instance }

  describe "switching between tabs" do
    before do
      # Mock the query to check the selected item in the table
      allow(Yast::UI).to receive(:QueryWidget).with(anything, :SelectedItems).and_return []
    end

    it "saves the state information of the tab" do
      expect(ui_state).to receive(:save_extra_info)
      tabs_widget.switch_page(devices_tab)
    end

    it "correctly updates the page in UIState" do
      expect(ui_state).to receive(:switch_to_tab).with(devices_tab.label).ordered
      expect(ui_state).to receive(:switch_to_tab).with(nil).ordered

      tabs_widget.switch_page(devices_tab)
      tabs_widget.switch_page(overview_tab)
    end
  end

  describe "#state_info" do
    before do
      allow(tabs_widget).to receive(:current_page).and_return tab
    end

    let(:tab_content) { Yast::CWM.widgets_in_contents([tab]) }
    let(:table) { tab_content.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) } }
    let(:open) { { "id1" => true, "id2" => false } }

    context "if the overview tab is currently selected" do
      let(:tab) { overview_tab }

      it "returns a hash with the id of the overview table and its corresponding open items" do
        expect(table).to receive(:ui_open_items).and_return open
        expect(subject.state_info).to eq(table.widget_id => open)
      end
    end

    context "if the used devices tab is currently selected" do
      let(:tab) { devices_tab }

      it "returns a hash with the id of the used devices table and its corresponding open items" do
        expect(table).to receive(:ui_open_items).and_return open
        expect(subject.state_info).to eq(table.widget_id => open)
      end
    end
  end
end
