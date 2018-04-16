#!/usr/bin/env rspec
# encoding: utf-8

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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/main"

describe Y2Partitioner::Dialogs::Main do
  before { devicegraph_stub("one-empty-disk.yml") }

  subject { described_class.new }

  include_examples "CWM::Dialog"

  describe "#run" do
    before do
      allow(Yast::ProductFeatures).to receive(:GetSection).with("partitioning")
        .and_return(partitioning_section)

      allow_any_instance_of(CWM::Dialog).to receive(:run).and_return(:next)
    end

    let(:partitioning_section) { { "expert_partitioner_warning" => warning } }

    let(:system_graph) { Y2Partitioner::DeviceGraphs.instance.system }

    let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

    context "when the settings does not contain 'expert_partitioner_warning'" do
      let(:warning) { false }

      it "does not show the partitioner warning" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.run(system_graph, current_graph)
      end

      it "returns the result of the dialog" do
        expect(subject.run(system_graph, current_graph)).to eq(:next)
      end
    end

    context "when the settings are configured to not show the partitioner warning" do
      let(:warning) { false }

      it "does not show the partitioner warning" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.run(system_graph, current_graph)
      end

      it "returns the result of the dialog" do
        expect(subject.run(system_graph, current_graph)).to eq(:next)
      end
    end

    context "when the settings are configured to show the partitioner warning" do
      let(:warning) { true }

      before do
        allow(Yast2::Popup).to receive(:show).and_return(answer)
      end

      let(:answer) { nil }

      it "shows the partitioner warning" do
        expect(Yast2::Popup).to receive(:show)

        subject.run(system_graph, current_graph)
      end

      context "and the user continues" do
        let(:answer) { :continue }

        it "returns the result of the dialog" do
          expect(subject.run(system_graph, current_graph)).to eq(:next)
        end
      end

      context "and the user cancels" do
        let(:answer) { :cancel }

        it "returns :back" do
          expect(subject.run(system_graph, current_graph)).to eq(:back)
        end
      end
    end
  end
end
