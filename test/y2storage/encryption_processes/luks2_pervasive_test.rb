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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::EncryptionProcesses::Pervasive do
  subject(:process) { described_class.new(method) }
  let(:method) { double }

  describe ".used_for?" do
    let(:encryption) { double(Y2Storage::Encryption, type: type, cipher: cipher) }

    context "when the encryption type is LUKS2 and the encryption cipher is paes-xts-plain64" do
      let(:type) { Y2Storage::EncryptionType::LUKS2 }
      let(:cipher) { "paes-xts-plain64" }

      it "returns true" do
        expect(described_class.used_for?(encryption)).to eq(true)
      end
    end

    context "when the encryption type is LUKS1 and the encryption cipher is paes-xts-plain64" do
      let(:type) { Y2Storage::EncryptionType::LUKS1 }
      let(:cipher) { "paes-xts-plain64" }

      it "returns false" do
        expect(described_class.used_for?(encryption)).to eq(false)
      end
    end

    context "when the encryption type is LUKS2 and the encryption cipher is aes-xts-plain64" do
      let(:type) { Y2Storage::EncryptionType::LUKS2 }
      let(:cipher) { "aes-xts-plain64" }

      it "returns false" do
        expect(described_class.used_for?(encryption)).to eq(false)
      end
    end
  end
end
