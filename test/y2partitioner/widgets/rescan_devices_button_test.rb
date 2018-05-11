require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/rescan_devices_button"
require_relative "#{TEST_PATH}/support/partitioner_reprobe_examples"

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
    let(:handle_args) { [] }

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
      before { allow(Yast::Stage).to receive(:initial).and_return install }

      context "during installation" do
        let(:install) { true }
        before { allow(manager).to receive(:activate).and_return true }

        include_examples "reprobing"

        it "runs activation again" do
          expect(manager).to receive(:activate).and_return true
          subject.handle
        end

        it "raises an exception if activation fails" do
          allow(manager).to receive(:activate).and_return false
          expect { subject.handle }.to raise_error(Y2Partitioner::ForcedAbortError)
        end
      end

      context "in an installed system" do
        let(:install) { false }

        include_examples "reprobing"

        it "does not re-run activation" do
          expect(manager).to_not receive(:activate)
          subject.handle
        end
      end
    end
  end
end
