require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/rescan_devices_button"

describe Y2Partitioner::Widgets::RescanDevicesButton do
  before do
    Y2Storage::StorageManager.create_test_instance
    # Ensure old values have been queried at least once
    manager.probed
    manager.staging
  end

  let(:manager) { Y2Storage::StorageManager.instance }

  subject { described_class.new }

  include_examples "CWM::PushButton"

  describe "#handle" do
    before do
      allow(Yast::Popup).to receive(:YesNo).and_return(accepted)
    end

    let(:accepted) { true }

    it "shows a confirm popup" do
      expect(Yast::Popup).to receive(:YesNo)
      subject.handle
    end

    context "when rescanning is canceled" do
      let(:accepted) { false }

      it "returns nil" do
        expect(subject.handle).to be_nil
      end
    end

    context "when rescanning is accepted" do
      let(:accepted) { true }

      it "shows an status message" do
        expect(Yast::Popup).to receive(:Feedback)
        subject.handle
      end

      it "probes again" do
        expect(manager).to receive(:probe).and_return(true)
        subject.handle
      end

      it "refreshes devicegraphs for the expert partitioner" do
        expect(Y2Partitioner::DeviceGraphs).to receive(:create_instance)
        subject.handle
      end

      it "returns :redraw" do
        expect(subject.handle).to eq(:redraw)
      end

      context "and the probing could not be correctly performed" do
        before do
          allow(manager).to receive(:probe).and_return(false)
        end

        it "raises an exception" do
          expect { subject.handle }.to raise_error(Y2Partitioner::ForcedAbortError)
        end
      end
    end
  end
end
