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
require "storage/boot_requirements_strategies"
require "storage/storage_manager"

module Yast
  module Storage
    #
    # Class that can check requirements for the different kinds of boot
    # partition: /boot, EFI-boot, PReP.
    #
    # TO DO: Check with arch maintainers if the requirements are correct.
    #
    # See also
    # https://github.com/yast/yast-bootloader/blob/master/SUPPORTED_SCENARIOS.md
    #
    class BootRequirementsChecker
      include Yast::Logger

      class Error < RuntimeError
      end

      def initialize(settings, disk_analyzer)
        @settings = settings
        @disk_analyzer = disk_analyzer
      end

      def needed_partitions
        strategy.needed_partitions
      end

    protected

      attr_reader :settings
      attr_reader :disk_analyzer

      def arch
        @arch ||= StorageManager.instance.arch
      end

      def strategy
        return @strategy unless @strategy.nil?

        if arch.x86? && arch.efiboot?
          @strategy = BootRequirementsStrategies::UEFI.new(settings, disk_analyzer)
        elsif arch.s390?
          @strategy = BootRequirementsStrategies::ZIPL.new(settings, disk_analyzer)
        elsif arch.ppc?
          @strategy = BootRequirementsStrategies::PReP.new(settings, disk_analyzer)
        end

        # Fallback to Legacy as default
        @strategy ||= BootRequirementsStrategies::Legacy.new(settings, disk_analyzer)
      end
    end
  end
end
