#!/usr/bin/env rspec

# Copyright (c) [2017] SUSE LLC
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

      it "does not create a new UIState instance" do
        expect(Y2Partitioner::UIState).to_not receive(:create_instance)

        subject.handle
      end

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

        it "creates a new UIState instance" do
          expect(Y2Partitioner::UIState).to receive(:create_instance)

          subject.handle
        end

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

        it "creates a new UIState instance" do
          expect(Y2Partitioner::UIState).to receive(:create_instance)

          subject.handle
        end

        it "does not re-run activation" do
          expect(manager).to_not receive(:activate)
          subject.handle
        end
      end
    end
  end
end
