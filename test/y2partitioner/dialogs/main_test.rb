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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/main"

describe Y2Partitioner::Dialogs::Main do
  before do
    devicegraph_stub("empty_hard_disk_50GiB")

    allow(Yast::Mode).to receive(:installation).and_return(installation)

    devicegraphs = Y2Partitioner::DeviceGraphs.instance
    allow(devicegraphs).to receive(:devices_edited?).and_return(devices_edited)

    allow(Y2Partitioner::DeviceGraphs).to receive(:instance).and_return(devicegraphs)
  end

  let(:installation) { true }

  let(:devices_edited) { false }

  let(:system_graph) { Y2Partitioner::DeviceGraphs.instance.system }

  let(:initial_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(system_graph, initial_graph) }

  include_examples "CWM::Dialog"

  describe "#run" do
    before do
      allow_any_instance_of(CWM::Dialog).to receive(:run).and_return(dialog_result)
    end

    let(:dialog_result) { nil }

    shared_examples "actions when accepts" do
      it "does not show a summary dialog" do
        expect(Y2Partitioner::Dialogs::Summary).to_not receive(:run)
        subject.run
      end

      it "stores the current devicegraph" do
        expect(subject.device_graph).to be_nil
        subject.run
        expect(subject.device_graph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end

      it "return :next" do
        expect(subject.run).to eq(:next)
      end
    end

    context "when running during installation" do
      let(:installation) { true }

      context "and the user goes back" do
        let(:dialog_result) { :back }

        it "returns :back" do
          expect(subject.run).to eq(:back)
        end
      end

      context "and the user cancels" do
        let(:dialog_result) { :abort }

        it "returns :back" do
          expect(subject.run).to eq(:back)
        end
      end

      context "and there are no changes" do
        let(:devices_edited) { false }

        context "and the user accepts the dialog (next)" do
          let(:dialog_result) { :next }

          include_examples "actions when accepts"
        end
      end

      context "and there are changes" do
        let(:devices_edited) { true }

        context "and the user accepts the dialog (next)" do
          let(:dialog_result) { :next }

          include_examples "actions when accepts"
        end
      end
    end

    context "when running in an installed system" do
      let(:installation) { false }

      context "and the user aborts" do
        let(:dialog_result) { :abort }

        it "returns :abort" do
          expect(subject.run).to eq(:abort)
        end
      end

      context "and there are no changes" do
        let(:devices_edited) { false }

        context "and the user accepts the dialog (next)" do
          let(:dialog_result) { :next }

          include_examples "actions when accepts"
        end
      end

      context "and there are changes" do
        let(:devices_edited) { true }

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
              expect(subject.device_graph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
            end

            it "return :next" do
              expect(subject.run).to eq(:next)
            end
          end
        end
      end
    end
  end

  describe "#abort_button" do
    context "when running during installation" do
      let(:installation) { true }

      it "returns 'Cancel' label" do
        expect(subject.abort_button).to eq(Yast::Label.CancelButton)
      end
    end

    context "when running in an installed system" do
      let(:installation) { false }

      it "returns 'Abort' label" do
        expect(subject.abort_button).to eq(Yast::Label.AbortButton)
      end
    end
  end

  describe "#next_button" do
    context "when running during installation" do
      let(:installation) { true }

      it "returns 'Accept' label" do
        expect(subject.next_button).to eq(Yast::Label.AcceptButton)
      end
    end

    context "when running in an installed system" do
      let(:installation) { false }

      context "and there are no changes" do
        let(:devices_edited) { false }

        it "returns 'Finish' label" do
          expect(subject.next_button).to eq(Yast::Label.FinishButton)
        end
      end

      context "and there are changes" do
        let(:devices_edited) { true }

        it "returns 'Next' label" do
          expect(subject.next_button).to eq(Yast::Label.NextButton)
        end
      end
    end
  end

  shared_examples "quiting partitioner" do
    context "when there are no changes" do
      let(:devices_edited) { false }

      it "does not show a confirmation popup" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.send(tested_method)
      end

      it "aborts (returns true)" do
        expect(subject.send(tested_method)).to eq(true)
      end
    end

    context "when there are changes" do
      let(:devices_edited) { true }

      before do
        allow(Yast2::Popup).to receive(:show).and_return(accept)
      end

      let(:accept) { nil }

      it "shows a confirmation popup" do
        expect(Yast2::Popup).to receive(:show)

        subject.send(tested_method)
      end

      context "and the user accepts" do
        let(:accept) { :yes }

        it "aborts (returns true)" do
          expect(subject.send(tested_method)).to eq(true)
        end
      end

      context "and the user does not accept" do
        let(:accept) { :no }

        it "does not abort (returns false)" do
          expect(subject.send(tested_method)).to eq(false)
        end
      end
    end
  end

  describe "#abort_handler" do
    let(:tested_method) { :abort_handler }

    include_examples "quiting partitioner"
  end

  describe "#back_handler" do
    let(:tested_method) { :back_handler }

    include_examples "quiting partitioner"
  end
end
