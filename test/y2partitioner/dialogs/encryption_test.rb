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
require "y2partitioner/dialogs/encryption"

describe Y2Partitioner::Dialogs::Encryption do
  let(:controller) { double("FilesystemController", wizard_title: "Title", actions: actions) }

  subject(:dialog) { described_class.new(controller) }

  context "when :encrypt is the only possible action" do
    let(:actions) { [:encrypt] }

    include_examples "CWM::Dialog"

    describe "#contents" do
      it "delegates everything to an EncryptPassword widget " do
        content = dialog.contents.params
        expect(content.size).to eq 1
        expect(content.first).to be_a Y2Partitioner::Widgets::EncryptPassword
      end
    end
  end

  context "when :keep and :encrypt are both possible actions" do
    let(:actions) { [:keep, :encrypt] }

    include_examples "CWM::Dialog"

    describe "#contents" do
      it "delegates everything to an Encryption::Action widget " do
        content = dialog.contents.params
        expect(content.size).to eq 1
        expect(content.first).to be_a Y2Partitioner::Dialogs::Encryption::ActionWidget
      end
    end
  end
end

describe Y2Partitioner::Dialogs::Encryption::ActionWidget do
  let(:controller) do
    double("FilesystemController", actions: [:keep, :encrypt], encryption: encryption)
  end

  let(:encryption) { double("Encryption", type: Y2Storage::EncryptionType::LUKS) }

  subject(:widget) { described_class.new(controller) }

  include_examples "CWM::CustomWidget"

  describe "#help" do
    it "returns a string" do
      expect(widget.help).to be_a(String)
    end
  end

  describe "#store" do
    before do
      allow(widget).to receive(:value).and_return :the_value
      allow(widget).to receive(:current_widget)
    end

    it "sets #action in the controller" do
      expect(controller).to receive(:action=).with(:the_value)
      widget.store
    end
  end

  describe "#init" do
    before do
      allow(controller).to receive(:action).and_return :the_value
    end

    it "sets #value to the action given by the controller" do
      expect(widget).to receive(:value=).with(:the_value)
      widget.init
    end
  end
end
