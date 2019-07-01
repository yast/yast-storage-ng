#!/usr/bin/env rspec
# Copyright (c) [2018] SUSE LLC
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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/device_graph_with_buttons"
require "tempfile"

describe Y2Partitioner::Widgets::DeviceGraphWithButtons do
  before do
    devicegraph_stub("complex-lvm-encrypt")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:visual_device_graph) { double("VisualDeviceGraph") }
  let(:xml_button) { double("SaveDeviceGraphButton") }
  let(:gv_button) { double("SaveDeviceGraphButton") }
  let(:pager) { double("OverviewTreePager") }

  subject(:widget) { described_class.new(device_graph, pager) }

  include_examples "CWM::CustomWidget"

  describe "#contents" do
    it "includes the graph and the two buttons for saving" do
      expect(Y2Partitioner::Widgets::VisualDeviceGraph).to receive(:new)
        .with(device_graph, pager).and_return visual_device_graph
      expect(Y2Partitioner::Widgets::SaveDeviceGraphButton).to receive(:new)
        .with(device_graph, :xml).and_return xml_button
      expect(Y2Partitioner::Widgets::SaveDeviceGraphButton).to receive(:new)
        .with(device_graph, :gv).and_return gv_button

      contents = widget.contents

      found = contents.nested_find { |i| i == visual_device_graph }
      expect(found).to_not be_nil
      found = contents.nested_find { |i| i == xml_button }
      expect(found).to_not be_nil
      found = contents.nested_find { |i| i == gv_button }
      expect(found).to_not be_nil
    end
  end

  describe Y2Partitioner::Widgets::SaveDeviceGraphButton do
    subject(:widget) { described_class.new(device_graph, format) }

    around do |example|
      # Extra "begin" forced by rubocop

      @tmp_file = Tempfile.new("graph")
      example.run
    ensure
      @tmp_file.close!

    end

    context "for the XML format" do
      let(:format) { :xml }

      include_examples "CWM::PushButton"

      describe "#label" do
        it "returns the correct label" do
          expect(widget.label).to include "XML"
        end
      end

      describe "#handle" do
        before do
          allow(Yast::UI).to receive(:AskForSaveFileName).and_return @tmp_file.path
        end

        it "exports the device graph to XML with the given file name" do
          expect(@tmp_file.read).to be_empty

          widget.handle
          content = @tmp_file.read

          expect(content).to start_with "<?xml version="
          expect(content).to include "<name>/dev/sda4</name>"
          expect(content).to include "<name>/dev/mapper/cr_sda4</name>"
          expect(content).to include "<name>/dev/sdg</name>"
          expect(content).to include "<uuid>abcdefgh-ijkl-mnop-qrst-uvwxyzzz</uuid>"
        end

        context "if an error is raised writing the file" do
          before do
            allow(device_graph).to receive(:save).and_raise Storage::Exception
          end

          it "shows a pop-up to the user" do
            expect(Yast::Popup).to receive(:Error)
            widget.handle
          end

          it "does nothing about the file content" do
            widget.handle
            expect(@tmp_file.read).to be_empty
          end
        end
      end
    end

    context "for the Graphviz format" do
      let(:format) { :gv }

      include_examples "CWM::PushButton"

      describe "#label" do
        it "returns the correct label" do
          expect(widget.label).to include "Graphviz"
        end
      end

      describe "#handle" do
        before do
          allow(Yast::UI).to receive(:AskForSaveFileName).and_return @tmp_file.path
        end

        it "exports the device graph to Dot format with the given file name" do
          expect(@tmp_file.read).to be_empty

          widget.handle
          content = @tmp_file.read

          expect(content).to include "digraph G {"
          expect(content).to include "label=\"/dev/sda4\""
          expect(content).to include "label=cr_sda4"
          expect(content).to include "label=\"/dev/sdg\""
        end

        context "if an error is raised writing the file" do
          before do
            allow(device_graph).to receive(:write_graphviz).and_raise Storage::Exception
          end

          it "shows a pop-up to the user" do
            expect(Yast::Popup).to receive(:Error)
            widget.handle
          end

          it "does nothing about the file content" do
            widget.handle
            expect(@tmp_file.read).to be_empty
          end
        end
      end
    end
  end
end
