#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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

require "yast"
require_relative "./proposal_volume"
require_relative "./disk_size"
require "pp"

module Yast
  module Storage
    #
    # Class that can check requirements for the different kinds of boot
    # partition: /boot, EFI-boot, PReP.
    #
    # TO DO: Check with arch maintainers if the requirements are correct.
    #
    class BootRequirementsChecker
      include Yast::Logger

      def initialize(settings)
        Yast.import "Arch"
        @settings = settings
      end

      def needed_partitions
        boot_volumes = []
        boot_volumes << make_efi_boot_partition if efi_boot_partition_needed?
        boot_volumes << make_boot_partition     if boot_partition_needed?
        boot_volumes << make_prep_partition     if prep_partition_needed?
        boot_volumes
      end

      def boot_partition_needed?
        return true if @settings.use_lvm && @settings.encrypt_volume_group
        false
      end

      def efi_boot_partition_needed?
        # TO DO
        false
      end

      def prep_partition_needed?
        # TO DO
        Arch.ppc
      end

      private

      def make_boot_partition
        vol = ProposalVolume.new("/boot", ::Storage::EXT4)
        vol.min_size = DiskSize.MiB(512) # TO DO
        vol.max_size = DiskSize.MiB(512) # TO DO
        vol.desired_size = vol.min_size
        vol.can_live_on_logical_volume = false
        vol
      end

      def make_efi_boot_partition
        vol = ProposalVolume.new("/boot/efi", ::Storage::VFAT)
        vol.can_live_on_logical_volume = false
        # TO DO
        vol
      end

      def make_prep_partition
        vol = ProposalVolume.new("PReP", ::Storage::VFAT)
        vol.can_live_on_logical_volume = false
        # TO DO
        vol
      end
    end
  end
end
