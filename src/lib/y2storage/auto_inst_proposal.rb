# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "y2storage/storage_manager"
require "y2storage/disk_analyzer"
require "y2storage/proposal/partition_killer"
require "y2storage/proposal/lvm_helper"
require "y2storage/exceptions"
require "y2storage/skip_list"

module Y2Storage
  # Class to calculate a storage proposal for autoinstallation
  #
  # @example Example
  #   profile = Yast::Profile.current["partitioning"]
  #   proposal = Y2Storage::AutoInstProposal.new(partitioning)
  #   proposal.proposed?            # => false
  #   proposal.proposed_devicegraph # => nil
  #   proposal.planned_devices      # => nil
  #
  #   proposal.propose   # => Performs the calculation
  #
  #   proposal.proposed?            # => true
  #   proposal.proposed_devicegraph # Proposed layout
  class AutoInstProposal
    include Yast::Logger

    # @return [Hash] Partitioning information from an AutoYaST profile
    attr_reader :partitioning

    # @return [Devicegraph] Initial device graph
    attr_reader :initial_devicegraph

    # Planned devices calculated by the proposal, nil if the proposal has not
    # been calculated yet
    # @return [Array<Planned::Device>]
    #
    attr_reader :planned_devices

    # Proposed layout of devices, nil if the proposal has not been
    # calculated yet
    # @return [Devicegraph]
    attr_reader :proposed_devicegraph

    alias_method :devices, :proposed_devicegraph

    # Constructor
    #
    # @param disk_analyzer [DiskAnalyzer] Disk analyzer
    # @param partitioning [Array<Hash>] Partitioning schema from an AutoYaST profile
    # @param devicegraph  [Devicegraph] starting point. If nil, then probed devicegraph
    #   will be used
    def initialize(disk_analyzer: nil, partitioning: [], devicegraph: nil)
      @partitioning = partitioning
      @proposed = false
      @initial_devicegraph = devicegraph
      @disk_analyzer = disk_analyzer
    end

    # Checks whether the proposal has already been calculated
    # @return [Boolean]
    def proposed?
      @proposed
    end

    # Calculates the proposal
    #
    # @raise [UnexpectedCallError] if called more than once
    # @raise [NoDiskSpaceError] if there is no enough space to perform the installation
    def propose
      raise UnexpectedCallError if proposed?
      devicegraph = initial_devicegraph.dup

      # By now, consider only regular disks
      disks = partitioning.select { |i| i.fetch("type", :CT_DISK) == :CT_DISK }

      # First, assign fixed drives
      fixed_disks, flexible_disks = disks.partition { |i| i["device"] && !i["device"].empty? }
      drives = fixed_disks.each_with_object({}) do |disk, memo|
        memo[disk["device"]] = disk
      end

      flexible_disks.reduce(drives) do |disk, memo|
        disk_name = first_usable_disk(disk, devicegraph, drives)
        memo[disk_name] = disk
      end

      # TODO: each_with_object
      planned_partitions = []
      drives.each do |name, description|
        disk = Disk.find_by_name(devicegraph, name)
        delete_stuff(devicegraph, disk, description)
        planned_partitions.concat(plan_partitions(devicegraph, disk, description))
      end

      if planned_partitions.empty?
        Y2Storage::ProposalSettings.new_for_current_product
        Y2Storage::Proposal.new(settings: proposal_settings)
        proposal.propose
        # TODO: Proposal con ciertas settings
        # (no separate home, max_root = unlimited, delete_x :none...)
        return
      end

      # TODO: test
      checker = BootRequirementsChecker.new(devicegraph, planned_devices: planned_partitions)
      planned_partitions.concat(checker.needed_partitions)

      # TODO: lvm_helper no obligatorio
      calculator = Proposal::PartitionsDistributionCalculator.new(Proposal::LvmHelper.new([]))

      disks = drives.map { |name, _x| Disk.find_by_name(devicegraph, name) }
      # FIXME: spaces = disks.map(&:free_disk_spaces).flatten
      spaces = disks.map(&:free_spaces).flatten
      dist = calculator.best_distribution(planned_partitions, spaces)

      part_creator = Proposal::PartitionCreator.new(devicegraph)

      # To extend in the future with planned_volumes, etc.
      @planned_devices = planned_partitions
      @proposed_devicegraph = part_creator.create_partitions(dist)
      @proposed = true

      nil
    end

    def first_usable_disk(disk_description, devicegraph, drives)
      devicegraph.disks.each do |disk|
        next if drives.keys.include?(disk.name)
        next if skipped?(disk_description, disk)

        return disk.name
      end
      nil
    end

    def skipped?(a, b)
      false
    end

    # Delete unwanted partitions for the given disk
    #
    # @param disk        [Y2Storage::Disk] Disk
    # @param description [Hash] Drive description from AutoYaST
    # @option description [Boolean] "initialize" Initialize the device
    # @option description [String]  "use"        Partitions to remove ("all", "linux", nil)
    def delete_stuff(devicegraph, disk, description)
      if description["initialize"]
        disk.remove_descendants
        return
      end

      # TODO: resizing of partitions

      case description["use"]
      when "all"
        disk.partition_table.remove_descendants if disk.partition_table
      when "linux"
        delete_linux_partitions(devicegraph, disk)
      end
    end

    def plan_partitions(devicegraph, disk, description)
      result = []
      description["partitions"].each do |part_description|
        # TODO: fix Planned::Partition.initialize
        part = Y2Storage::Planned::Partition.new(nil, nil)
        part.disk = disk.name
        # part.bootable no está en el perfil (¿existe lógica?)
        part.filesystem_type = filesystem_for(part_description["filesystem"])
        part.partition_id = 131 # TODO: El que venga. Si nil, swap o linux
        if part_description["crypt_fs"]
          part.encryption_password = part_description["crypt_key"]
        end
        part.mount_point = part_description["mount"]

        if part_description["create"]
          part.label = part_description["label"]
          part.uuid = part_description["uuid"]
        else
          # TODO: tener en cuenta reusar PERO FORMATEANDO
          # TODO: error si 1) no se especificó un dispositivo o 2) no existe
          partition_to_reuse = find_partition_to_reuse(devicegraph, part_description)
          part.reuse = partition_to_reuse.name unless partition_to_reuse.nil?
        end

        # Sizes: leave out reducing fixed sizes and 'auto'
        min_size, max_size = sizes_for(part_description, disk)
        part.min_size = min_size
        part.max_size = max_size
        result << part
      end

      result
    end

    SIZE_REGEXP = /([\d,.]+)?([a-zA-Z%]+)/
    def sizes_for(description, disk)
      normalized_size = description["size"].to_s.strip.downcase
      return [disk.min_grain, DiskSize.unlimited] if normalized_size == "max" || normalized_size.empty?

      _all, number, unit = SIZE_REGEXP.match(normalized_size).to_a
      size =
        if unit == "%"
          percent = number.to_f
          (disk.size * percent) / 100.0
        else
          DiskSize.parse(description["size"], legacy_units: true)
        end
      [size, size]
    end

    def filesystem_for(filesystem)
      Y2Storage::Filesystems::Type.find(filesystem)
    end

    # Disk analyzer used to analyze the initial devicegraph
    #
    # @return [DiskAnalyzer]
    def disk_analyzer
      @disk_analyzer ||= DiskAnalyzer.new(initial_devicegraph)
    end

    def delete_linux_partitions(devicegraph, disk)
      partition_killer = Proposal::PartitionKiller.new(devicegraph)
      parts = disk_analyzer.linux_partitions(disk)
      parts.map(&:name).each { |n| partition_killer.delete(n) }
    end

    def find_partition_to_reuse(devicegraph, part_description)
      if part_description["partition_nr"]
        devicegraph.partitions.find { |p| p.number == part_description["partition_nr"] }
      elsif part_description["label"]
        devicegraph.partitions.find { |p| p.filesystem_label == part_description["label"] }
      end
    end
  end
end
