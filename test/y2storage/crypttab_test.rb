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
require "y2storage/crypttab"

describe Y2Storage::Crypttab do
  before do
    fake_scenario(scenario)
  end

  subject { described_class.new(path) }

  let(:path) { File.join(DATA_PATH, crypttab_name) }

  let(:scenario) { "empty_hard_disk_50GiB" }

  describe "#initialize" do
    let(:crypttab_name) { "crypttab" }

    it "reads and sets the fstab entries" do
      entries = subject.entries

      expect(entries.size).to eq(3)

      expect(entries).to include(
        an_object_having_attributes(name: "luks1", device: "/dev/sda1", password: "passw1",
          crypt_options: ["option1", "option2=2"]),
        an_object_having_attributes(name: "luks2", device: "/dev/sda2", password: "passw2"),
        an_object_having_attributes(name: "luks3", device: "/dev/sda3", password: "passw3")
      )
    end

    context "when there is some problem reading the entries" do
      let(:crypttab_name) { "not_exist" }

      it "sets an empty list of entries" do
        expect(subject.entries).to be_empty
      end
    end
  end
end
