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
  before do
    fake_scenario("one-empty-disk")

    allow(Yast::Mode).to receive(:installation).and_return(installation)
  end

  let(:installation) { true }

  let(:system_graph) { Y2Storage::StorageManager.instance.probed }

  let(:initial_graph) { Y2Storage::StorageManager.instance.staging }

  subject { described_class.new(system_graph, initial_graph) }

  include_examples "CWM::Dialog"

  describe "#run" do
    before do
      allow_any_instance_of(CWM::Dialog).to receive(:run).and_return(dialog_result)

      allow(Y2Partitioner::DeviceGraphs).to receive(:instance).and_return(device_graphs)
      allow(device_graphs).to receive(:current).and_return(new_graph)
    end

    let(:device_graphs) { instance_double(Y2Partitioner::DeviceGraphs) }

    let(:new_graph) { nil }

    let(:dialog_result) { nil }

    shared_examples "actions when accepts" do
      it "does not show a summary dialog" do
        expect(Y2Partitioner::Dialogs::Summary).to_not receive(:run)
        subject.run
      end

      it "saves the devicegraph" do
        expect(subject.device_graph).to be_nil
        subject.run
        expect(subject.device_graph).to eq(new_graph)
      end

      it "return :next" do
        expect(subject.run).to eq(:next)
      end
    end

    context "when running during installation" do
      let(:installation) { true }

      context "and there are no changes" do
        let(:new_graph) { initial_graph }

        context "and the user accepts the dialog (next)" do
          let(:dialog_result) { :next }

          include_examples "actions when accepts"
        end

        # TODO: Not implement yet because the current behaviour must be revised
        context "and the user goes back"

        # TODO: Not implement yet because the current behaviour must be revised
        context "and the user aborts"
      end

      context "and there are changes" do
        let(:storage) { Y2Storage::StorageManager.instance.storage }
        let(:new_graph) { Y2Storage::Devicegraph.new(storage.create_devicegraph("fake")) }

        context "and the user accepts the dialog (next)" do
          let(:dialog_result) { :next }

          include_examples "actions when accepts"
        end

        # TODO: Not implement yet because the current behaviour must be revised
        context "and the user goes back"

        # TODO: Not implement yet because the current behaviour must be revised
        context "and the user aborts"
      end
    end

    context "when running in an installed system" do
      let(:installation) { false }

      context "and there are no changes" do
        let(:new_graph) { initial_graph }

        context "and the user accepts the dialog (next)" do
          let(:dialog_result) { :next }

          include_examples "actions when accepts"
        end

        # TODO: Not implement yet because the current behaviour must be revised
        context "and the user aborts"
      end

      context "and there are changes" do
        let(:storage) { Y2Storage::StorageManager.instance.storage }
        let(:new_graph) { Y2Storage::Devicegraph.new(storage.create_devicegraph("fake")) }

        before do
          allow(Y2Partitioner::Dialogs::Summary).to receive(:run).and_return(summary_result)
        end

        let(:summary_result) { nil }

        context "and the user accepts the dialog (next)" do
          let(:dialog_result) { :next }

          it "shows a summary dialog" do
            expect(Y2Partitioner::Dialogs::Summary).to receive(:run)
            subject.run
          end

          context "and the user accepts the summary dialog (next)" do
            let(:summary_result) { :next }

            it "saves the devicegraph" do
              expect(subject.device_graph).to be_nil
              subject.run
              expect(subject.device_graph).to eq(new_graph)
            end

            it "return :next" do
              expect(subject.run).to eq(:next)
            end
          end

          # TODO: Not implement yet because the current behaviour must be revised
          context "and the user aborts"
        end

        # TODO: Not implement yet because the current behaviour must be revised
        context "and the user aborts"
      end
    end
  end

  context "#next_button" do
    context "when running during installation" do
      let(:installation) { true }

      it "returns 'Accept' label" do
        expect(subject.next_button).to eq(Yast::Label.AcceptButton)
      end
    end

    context "when running in an installed system" do
      let(:installation) { false }

      before do
        allow(Y2Partitioner::DeviceGraphs).to receive(:instance).and_return(device_graphs)
        allow(device_graphs).to receive(:current).and_return(new_graph)
      end

      let(:device_graphs) { instance_double(Y2Partitioner::DeviceGraphs) }

      context "and there are no changes" do
        let(:new_graph) { initial_graph }

        it "returns 'Finish' label" do
          expect(subject.next_button).to eq(Yast::Label.FinishButton)
        end
      end

      context "and there are changes" do
        let(:storage) { Y2Storage::StorageManager.instance.storage }
        let(:new_graph) { Y2Storage::Devicegraph.new(storage.create_devicegraph("fake")) }

        it "returns 'Next' label" do
          expect(subject.next_button).to eq(Yast::Label.NextButton)
        end
      end
    end
  end
end
