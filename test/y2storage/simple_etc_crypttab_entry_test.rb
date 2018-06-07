#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2storage/simple_etc_crypttab_entry"

describe Y2Storage::SimpleEtcCrypttabEntry do
  before do
    fake_scenario(scenario)
  end

  subject { crypttab_entry(name, device, password, crypt_options) }

  let(:name) { "cr_sda4" }

  let(:device) { "/dev/sda4" }

  let(:password) { "P4ssW0rd" }

  let(:crypt_options) { [] }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  let(:scenario) { "gpt_encryption" }

  describe "#find_device" do
    let(:sda4) { devicegraph.find_by_name("/dev/sda4") }

    context "when the crypttab device contains an UUID" do
      let(:device) { "UUID=123456-789" }

      it "returns nil (FIXME)" do
        expect(subject.find_device(devicegraph)).to be_nil
      end
    end

    context "when the crypttab device contains a LABEL" do
      let(:device) { "LABEL=device_laabel" }

      it "returns nil (FIXME)" do
        expect(subject.find_device(devicegraph)).to be_nil
      end
    end

    context "when the crypttab device contains a device path" do
      context "and the device does not exist" do
        let(:device) { "/dev/sdb1" }

        it "returns nil" do
          expect(subject.find_device(devicegraph)).to be_nil
        end
      end

      context "and the device exists" do
        let(:device) { "/dev/sda4" }

        it "returns the proper device" do
          expect(subject.find_device(devicegraph)).to eq(sda4)
        end
      end
    end
  end
end
