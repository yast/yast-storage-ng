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
require "y2storage/boot_requirements_strategies"
require "y2storage/storage_manager"

module Y2Storage
  #
  # Class that can check requirements for the different kinds of boot
  # partition: /boot, EFI-boot, PReP.
  #
  # See also
  # https://github.com/yast/yast-bootloader/blob/master/SUPPORTED_SCENARIOS.md
  #
  class BootRequirementsChecker
    include Yast::Logger

    class Error < RuntimeError
    end

    # Constructor
    #
    # @see #devicegraph
    # @see #planned_devices
    # @see #boot_disk_name
    def initialize(devicegraph, planned_devices: [], boot_disk_name: nil)
      @devicegraph = devicegraph
      @planned_devices = planned_devices
      @boot_disk_name = boot_disk_name
    end

    # Partitions needed in order to be able to boot the system
    #
    # @raise [BootRequirementsStrategies::Error] if adding partitions is not
    #     enough to make the system bootable
    #
    # @param target [Symbol] :desired means the sizes of the partitions should
    #   be the ideal ones, :min for generating the smallest functional
    #   partitions
    # @return [Array<Planned::Partition>]
    def needed_partitions(target = :desired)
      strategy.needed_partitions(target)
    rescue BootRequirementsStrategies::Error => error
      raise Error, error.message
    end

  protected

    # @return [Devicegraph] starting situation.
    attr_reader :devicegraph

    # @return [Array<Planned::Device>] devices that are already planned to be
    #   added to the starting devicegraph.
    attr_reader :planned_devices

    # @return [String, nil] device name of the disk that the system will try to
    #   boot first. Only useful in some scenarios like legacy boot.
    attr_reader :boot_disk_name

    def arch
      @arch ||= StorageManager.instance.arch
    end

    def strategy
      return @strategy unless @strategy.nil?

      klass =
        if arch.x86? && arch.efiboot?
          BootRequirementsStrategies::UEFI
        elsif arch.s390?
          BootRequirementsStrategies::ZIPL
        elsif arch.ppc?
          BootRequirementsStrategies::PReP
        else
          # Fallback to Legacy as default
          BootRequirementsStrategies::Legacy
        end
      @strategy ||= klass.new(devicegraph, planned_devices, boot_disk_name)
    end
  end
end
