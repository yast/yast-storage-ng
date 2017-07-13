require_relative "../test_helper"

require "y2partitioner/clients/main"

describe Y2Partitioner::Clients::Main do
  subject { described_class }

  describe ".run" do
    before do
      allow(Yast::Wizard).to receive(:OpenDialog)
      allow(Yast::Wizard).to receive(:CloseDialog)
      allow(Yast::CWM).to receive(:show)
      allow(Yast::Stage).to receive(:initial).and_return(false)
      Y2Storage::StorageManager.create_test_instance
    end

    describe "when committing is allowed" do
      it "asks, and commits when confirmed" do
        smanager = Y2Storage::StorageManager.instance

        expect(Yast::CWM).to receive(:show).and_return(:next)
        expect(Yast::Popup).to receive(:ContinueCancel).and_return(true)
        expect(smanager).to receive(:"staging=")
        # this also blocks the real #commit call
        expect(smanager).to receive(:commit)
        subject.run(allow_commit: true)
      end
    end

    describe "when commitig is disallowed" do
      it "tells so, and does not commit" do
        smanager = Y2Storage::StorageManager.instance

        expect(Yast::CWM).to receive(:show).and_return(:next)
        expect(Yast::Popup).to receive(:Message)
        expect(smanager).to_not receive(:"staging=")
        expect(smanager).to_not receive(:commit)

        subject.run(allow_commit: false)
      end
    end
  end
end
