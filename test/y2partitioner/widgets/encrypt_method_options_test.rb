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
require "y2partitioner/widgets/encrypt_method_options"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/encryption"

describe Y2Partitioner::Widgets::EncryptMethodOptions do
  subject { described_class.new(controller) }

  let(:fs_controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(device, "The title") }
  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:dev_name) { "/dev/sda" }

  let(:controller) { Y2Partitioner::Actions::Controllers::Encryption.new(fs_controller) }
  let(:random_swap) { Y2Storage::EncryptionMethod::RANDOM_SWAP }
  let(:luks1) { Y2Storage::EncryptionMethod::LUKS1 }

  before do
    devicegraph_stub("empty_hard_disk_50GiB.yml")
  end

  include_examples "CWM::CustomWidget"

  describe "#refresh" do
    let(:fake_random_swap_options) { CWM::Empty.new("__fake_plain_options__") }
    let(:fake_luks1_options) { CWM::Empty.new("__fake_luks1_options__") }

    before do
      allow(Y2Partitioner::Widgets::RandomOptions).to receive(:new).and_return(fake_random_swap_options)
      allow(Y2Partitioner::Widgets::Luks1Options).to receive(:new).and_return(fake_luks1_options)
    end

    it "generates the new content based on the selected method" do
      expect(Y2Partitioner::Widgets::RandomOptions).to receive(:new)
      subject.refresh(random_swap)

      expect(Y2Partitioner::Widgets::Luks1Options).to receive(:new)
      subject.refresh(luks1)
    end

    it "replaces the content using the new generated content" do
      expect(subject).to receive(:replace).with(fake_random_swap_options)
      subject.refresh(random_swap)

      expect(subject).to receive(:replace).with(fake_luks1_options)
      subject.refresh(luks1)
    end
  end

  describe Y2Partitioner::Widgets::RandomOptions do
    subject { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    describe "#contents" do
      it "displays a warning message" do
        texts = subject.contents.nested_find { |el| el.is_a?(Yast::Term) && el.value == :Label }.to_a

        expect(texts).to include(/careful/)
      end
    end
  end

  describe Y2Partitioner::Widgets::Luks1Options do
    subject { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    describe "#contents" do
      it "displays the encryption password widget" do
        expect(Y2Partitioner::Widgets::EncryptPassword).to receive(:new).with(controller)

        subject.contents
      end
    end
  end
end
