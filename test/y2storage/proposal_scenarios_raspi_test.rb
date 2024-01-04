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

require_relative "spec_helper"
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  describe "#propose in Raspberry Pi" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings:) }
    let(:architecture) { :aarch64 }
    let(:control_file) { "legacy_settings.xml" }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/proc/device-tree/model").and_return true
      allow(File).to receive(:read).with("/proc/device-tree/model").and_return "Raspberry Pi VERSION"
      allow(Yast::Encoding).to receive(:GetUtf8Lang).and_return true
    end

    context "installing in an empty card" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:expected_scenario) { "raspi_empty" }

      include_examples "proposed layout"
    end

    context "installing in a card with a firmware partition" do
      let(:scenario) { "raspi_firmware" }

      let(:reader) { double("Y2Storage::FilesystemReader").as_null_object }

      before do
        allow(Y2Storage::FilesystemReader).to receive(:new).and_return reader
        allow(reader).to receive(:efi?).and_return false
        allow(reader).to receive(:rpi_boot?).and_return true
      end

      include_examples "proposed layout"
    end
  end
end
