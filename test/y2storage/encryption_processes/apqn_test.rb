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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::EncryptionProcesses::Apqn do
  def lszcrypt(file)
    File.read(File.join(DATA_PATH, "lszcrypt", "#{file}.txt"))
  end

  before do
    Y2Storage::StorageManager.create_test_instance

    allow(Yast::Execute).to receive(:locally!).with(/lszcrypt/, anything).and_return(lszcrypt_output)
  end

  let(:lszcrypt_output) { lszcrypt("three-apqns") }

  describe ".all" do
    it "returns a list of Apqn objets" do
      expect(described_class.all).to all(be_a(Y2Storage::EncryptionProcesses::Apqn))
    end

    it "returns all available APQNs" do
      expect(described_class.all.map(&:name)).to contain_exactly("01.0001", "01.0002", "01.0003")
    end

    context "when the command to find APQNs fails" do
      before do
        allow(Yast::Execute).to receive(:locally!).with(/lszcrypt/, anything)
          .and_raise(Cheetah::ExecutionFailed.new("", "", "", ""))
      end

      it "returns an empty list" do
        expect(described_class.all).to be_empty
      end
    end
  end

  describe ".online" do
    it "returns all online APQNs" do
      expect(described_class.online.map(&:name)).to contain_exactly("01.0001", "01.0003")
    end
  end

  subject { described_class.new("01.0001", "type", "mode", status) }

  let(:status) { "online" }

  describe "#name" do
    it "returns the APQN name" do
      expect(subject.name).to eq("01.0001")
    end
  end

  describe "online?" do
    context "when the APQN is online" do
      let(:status) { "online" }

      it "returns true" do
        expect(subject.online?).to eq(true)
      end
    end

    context "when the APQN is offline" do
      let(:status) { "offline" }

      it "returns false" do
        expect(subject.online?).to eq(false)
      end
    end
  end
end
