#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

RSpec.shared_context "plain UEFI" do
  using Y2Storage::Refinements::SizeCasts

  context "if there are no EFI partitions" do
    let(:scenario) { "trivial" }

    it "requires only a new /boot/efi partition" do
      expect(checker.needed_partitions).to contain_exactly(
        an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
      )
    end
  end

  context "if there is already an EFI partition" do
    context "and it is not a suitable EFI partition (not enough size, invalid filesystem)" do
      let(:scenario) { "too_small_efi" }

      it "requires only a new /boot/efi partition" do
        expect(checker.needed_partitions).to contain_exactly(
          an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
        )
      end
    end

    context "and it is a suitable EFI partition (enough size, valid filesystem)" do
      let(:scenario) { "efi_not_mounted" }

      it "only requires to use the existing EFI partition" do
        expect(checker.needed_partitions).to contain_exactly(
          an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda1")
        )
      end
    end
  end
end
