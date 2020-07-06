#!/usr/bin/env rspec
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
# find current contact information at www.suse.com.

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2partitioner/icons"
require "y2partitioner/widgets/columns/encrypted"

describe Y2Partitioner::Widgets::Columns::Encrypted do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:device) { double(Y2Storage::Device) }

  describe "#value_for" do
    context "when the device does not respond to #encrypted?" do
      before do
        allow(device).to receive(:respond_to?).with(:encrypted?).and_return(false)
      end

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the device is encrypted" do
      before do
        allow(device).to receive(:encrypted?).and_return(true)
        allow(Yast::UI).to receive(:GetDisplayInfo).and_return("HasIconSupport" => icon_support)
      end

      context "and running with icon support" do
        let(:icon_support) { true }

        it "returns a Yast::Term" do
          expect(subject.value_for(device)).to be_a(Yast::Term)
        end

        it "contains the encrypted icon" do
          value = subject.value_for(device)
          icon_term = value.params.find { |param| param.is_a?(Yast::Term) && param.value == :icon }
          expect(icon_term.params).to include(Y2Partitioner::Icons::ENCRYPTED)
        end
      end

      context "but running without icon support" do
        let(:icon_support) { false }

        it "returns a string" do
          expect(subject.value_for(device)).to be_an(String)
        end
      end
    end
  end
end
