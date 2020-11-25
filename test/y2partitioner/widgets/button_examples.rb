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

require_relative "../test_helper"
require_relative "button_context"

require "cwm/rspec"

shared_examples "handle result" do
  context "if the action returns :finish" do
    let(:action_result) { :finish }

    it "returns :redraw" do
      expect(subject.handle).to eq(:redraw)
    end
  end

  context "if the action does not return :finish" do
    let(:action_result) { nil }

    it "returns nil" do
      expect(subject.handle).to be_nil
    end
  end
end

shared_examples "handle without device" do
  context "when no device is given" do
    let(:device) { nil }

    before do
      allow(Yast2::Popup).to receive(:show)
    end

    it "shows an error message" do
      expect(Yast2::Popup).to receive(:show)

      subject.handle
    end

    it "returns nil" do
      expect(subject.handle).to be_nil
    end
  end
end

shared_examples "add button" do
  let(:scenario) { "one-empty-disk" }

  include_context "action button context"

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "starts the action to create the device" do
      expect(action).to receive(:new)

      subject.handle
    end

    include_examples "handle result"
  end
end

shared_examples "button" do
  include_context "device button context"

  include_examples "CWM::PushButton"

  describe "#handle" do
    include_examples "handle without device"

    context "when a device is given" do
      it "starts the proper action over the device" do
        expect(action).to receive(:new).with(device)

        subject.handle
      end

      include_examples "handle result"
    end
  end
end
