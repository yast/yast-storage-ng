#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/widgets/encrypt_method"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/encryption"

describe Y2Partitioner::Widgets::EncryptMethod do
  subject(:widget) { described_class.new(enc_controller) }

  let(:fs_controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(device, "The title") }
  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:dev_name) { "/dev/sda" }

  let(:enc_controller) { Y2Partitioner::Actions::Controllers::Encryption.new(fs_controller) }
  let(:random_swap) { Y2Storage::EncryptionMethod::RANDOM_SWAP }
  let(:luks1) { Y2Storage::EncryptionMethod::LUKS1 }

  before do
    devicegraph_stub("empty_hard_disk_50GiB.yml")

    enc_controller.method = random_swap
  end

  describe "#init" do
    it "sets the current encryption method value" do
      expect(widget).to receive(:value=).with(random_swap)

      widget.init
    end
  end

  describe "#value" do
    let(:selected_method) { random_swap.to_sym }

    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(selected_method)
    end

    it "returns the selected encryption method" do
      expect(widget.value).to eq(random_swap)
    end
  end

  describe "#items" do
    let(:available_methods) { [random_swap, luks1] }

    before do
      allow(enc_controller).to receive(:methods).and_return(available_methods)
    end

    it "includes all available methods" do
      items = widget.items.map(&:first)
      expected_items = available_methods.map(&:to_sym)

      expect(items).to eq(expected_items)
    end
  end

  describe "#store" do
    let(:selected_method) { random_swap.to_sym }

    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(selected_method)
    end

    it "sets the selected encryption method" do
      expect(enc_controller).to receive(:method=).with(random_swap)

      widget.store
    end
  end
end
