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

require_relative "../../test_helper"
require_relative "help_fields_examples"

require "y2partitioner/widgets/description_section/blk_device"

describe Y2Partitioner::Widgets::DescriptionSection::BlkDevice do
  before { devicegraph_stub(scenario) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks" }

  let(:device) { current_graph.find_by_name("/dev/sda2") }

  subject { described_class.new(device) }

  describe "#value" do
    it "includes a section title" do
      expect(subject.value).to match(/<h3>.*<\/h3>/)
    end

    it "includes a list of entries" do
      expect(subject.value).to match(/<ul>.*<\/ul>/)
    end

    it "includes an entry about the device name" do
      expect(subject.value).to match(/Device:/)
    end

    it "includes an entry about the device size" do
      expect(subject.value).to match(/Size:/)
    end

    context "for a non encrypted device" do
      it "includes an entry about the encryption" do
        expect(subject.value).to match(/Encrypted: No/)
      end
    end

    context "for an encrypted device" do
      let(:scenario) { "encrypted_with_bios_boot" }

      context "with most of the encryption types" do
        it "includes an entry about the encryption including the encryption type" do
          expect(subject.value).to match(/Encrypted: Yes/)
          expect(subject.value).to match(/LUKS1/)
        end

        it "does not include any entry about LUKS2-specific attributes" do
          expect(subject.value).to_not match(/LUKS2 Label/)
          expect(subject.value).to_not match(/Derivation Function/)
        end
      end

      context "if LUKS2 is used as encryption type" do
        before { device.encrypt(method: :luks2, label: "something", pbkdf: "argon2i") }

        it "includes an entry about the encryption including the encryption type" do
          expect(subject.value).to match(/Encrypted: Yes/)
          expect(subject.value).to match(/LUKS2/)
        end

        it "does not include any entry about LUKS2-specific attributes" do
          expect(subject.value).to match(/LUKS2 Label: something/)
          expect(subject.value).to match(/Derivation Function \(PBKDF\): Argon2i/)
        end
      end
    end

    it "includes an entry about the udev by_path values" do
      expect(subject.value).to match(/Device Path:/)
    end

    it "includes an entry about the udev by_id values" do
      expect(subject.value).to match(/Device ID:/)
    end
  end

  describe "#help_fields" do
    let(:excluded_help_fields) { [] }

    include_examples "help fields"
  end
end
