#!/usr/bin/env rspec
# Copyright (c) [2021] SUSE LLC
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
require "y2partitioner/widgets/encrypt_label"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/encryption"

describe Y2Partitioner::Widgets::EncryptLabel do
  subject(:widget) { described_class.new(controller) }

  let(:controller) { double("Controllers::Encryption", label: initial_label) }
  let(:initial_label) { "initial" }
  let(:label) { "" }

  before do
    devicegraph_stub("mixed_disks.yml")

    # Needed by the CWM::InputField shared examples
    allow(subject).to receive(:value).and_return(label)
  end

  include_examples "CWM::InputField"

  describe "#init" do
    it "sets the current label value" do
      expect(widget).to receive(:value=).with(initial_label)

      widget.init
    end
  end

  describe "#store" do
    let(:label) { "lukslabel" }

    it "sets the selected pbkdf" do
      expect(controller).to receive(:label=).with(label)

      widget.store
    end
  end

  describe "#validate" do
    let(:fs_controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(device, "The title") }
    let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
    let(:device) { devicegraph.find_by_name(dev_name) }
    let(:dev_name) { "/dev/sdb2" }

    let(:controller) { Y2Partitioner::Actions::Controllers::Encryption.new(fs_controller) }

    before do
      sda2 = devicegraph.find_by_name("/dev/sda2")
      sda2.encrypt(method: :luks2, label: "existing")

      sdb1 = devicegraph.find_by_name("/dev/sdb1")
      sdb1.encrypt(method: :luks2)
    end

    context "when a label is entered" do
      context "and there is already a LUKS device with the given label" do
        let(:label) { "existing" }

        it "shows an popup error" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "and the LUKS device on the same device already has that label" do
        let(:dev_name) { "/dev/sda2" }
        let(:label) { "existing" }

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end

      context "and there is no other LUKS with the given label" do
        let(:label) { "foo" }

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end
    end

    context "when an empty label is entered" do
      let(:label) { "" }

      it "returns true" do
        expect(subject.validate).to eq(true)
      end
    end
  end
end
