#!/usr/bin/env rspec
# Copyright (c) [2025] SUSE LLC
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
require "y2partitioner/widgets/encrypt_auth_selector"
require "y2storage/encryption_authentication"
Yast.import "Arch"

describe Y2Partitioner::Widgets::EncryptAuthSelector do
  subject(:widget) { described_class.new(controller) }

  let(:initial_authentication) { "fido2" }
  let(:controller) do
    double("Controllers::Encryption",
      authentication: Y2Storage::EncryptionAuthentication.find(initial_authentication))
  end

  include_examples "CWM::ComboBox"

  describe "#init" do
    it "sets the current authentication value" do
      expect(widget).to receive(:value=).with(initial_authentication)

      widget.init
    end
  end

  describe "#value" do
    let(:selected_authentication) { "tpm2" }

    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(selected_authentication)
    end

    it "returns the selected authentication method" do
      expect(widget.value).to eq(selected_authentication)
    end
  end

  describe "#items" do
    before do
      allow(Yast::Arch).to receive(:has_tpm2).and_return(true)
    end

    it "includes all available authentication" do
      items = widget.items.map(&:first)

      expect(items).to contain_exactly("password", "tpm2", "tpm2+pin", "fido2")
    end
  end

  describe "#store" do
    let(:selected_authentication) { "password" }

    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(selected_authentication)
    end

    it "sets the selected authentication" do
      authentication = Y2Storage::EncryptionAuthentication.find(selected_authentication)
      expect(controller).to receive(:authentication=).with(authentication)

      widget.store
    end
  end
end
