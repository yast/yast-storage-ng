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
require "storage/planned_volume"
require "storage/planned_volumes_list"
require "storage/disk_size"
require "storage/boot_requirements_strategies"

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

      def initialize(settings, disk_analyzer)
        Yast.import "Arch"
        @settings = settings
        @disk_analyzer = disk_analyzer
      end

      def needed_partitions
        strategy.needed_partitions
      end

    protected

      attr_reader :settings
      attr_reader :disk_analyzer

      def strategy
        return @strategy unless @strategy.nil?

        # TODO: until we implement real strategies, let's always return Default
        @strategy = BootRequirementsStrategies::Default.new(settings, disk_analyzer)
        return @strategy

        # TODO: don't use Arch, but libstorage detection
        if Arch.i386 || Arch.x86_64
          # if UEFI
          # @strategy = BootRequirementsStrategies::UEFI.new(settings, disk_analyzer)
          # else
          # @strategy = BootRequirementsStrategies::Default.new(settings, disk_analyzer)
          # end
        elsif Arch.s390
          @strategy = BootRequirementsStrategies::ZIPL.new(settings, disk_analyzer)
        elsif Arch.ppc64
          @strategy = BootRequirementsStrategies::PReP.new(settings, disk_analyzer)
        elsif Arch.aarch64
          @strategy = BootRequirementsStrategies::UEFI.new(settings, disk_analyzer)
        else
          @strategy = BootRequirementsStrategies::Default.new(settings, disk_analyzer)
        end
        @strategy
      end
    end
  end
end
