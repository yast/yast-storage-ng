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
require "y2storage/disk_size"
require "y2storage/filesystems/type"
require "y2storage/planned"
require "y2storage/boot_requirements_strategies/analyzer"
require "y2storage/exceptions"

module Y2Storage
  module BootRequirementsStrategies
    class Error < Y2Storage::Error
    end

    # Base class for the strategies used to calculate the boot partitioning
    # requirements
    class Base
      include Yast::Logger
      extend Forwardable

      def_delegators :@analyzer,
        :boot_disk, :root_in_lvm?, :encrypted_root?, :btrfs_root?, :boot_ptable_type?

      # Constructor
      #
      # @see [BootRequirementsChecker#devicegraph]
      # @see [BootRequirementsChecker#planned_devices]
      # @see [BootRequirementsChecker#boot_disk_name]
      def initialize(devicegraph, planned_devices, boot_disk_name)
        @devicegraph = devicegraph
        @analyzer = Analyzer.new(devicegraph, planned_devices, boot_disk_name)
      end

      def needed_partitions(target)
        boot_partition_needed? ? [boot_partition(target)] : []
      end

    protected

      attr_reader :devicegraph

      def boot_partition_needed?
        false
      end

      def boot_partition(target)
        vol = Planned::Partition.new("/boot", Filesystems::Type::EXT4)
        vol.disk = boot_disk.name
        vol.min_size = target == :min ? DiskSize.MiB(100) : DiskSize.MiB(200)
        vol.max_size = DiskSize.MiB(500)
        vol
      end
    end
  end
end
