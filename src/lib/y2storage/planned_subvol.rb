# encoding: utf-8

# Copyright (c) [2012-2016] Novell, Inc.
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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
Yast.import "Arch"

module Y2Storage
  # Helper class to represent a subvolume as defined in control.xml
  #
  class PlannedSubvol
    include Yast::Logger

    attr_accessor :path, :copy_on_write, :archs

    COW_SUBVOL_PATHS = [
      "home",
      "opt",
      "srv",
      "tmp",
      "usr/local",
      "var/cache",
      "var/crash",
      "var/lib/machines",
      "var/lib/mailman",
      "var/lib/named",
      "var/log",
      "var/opt",
      "var/spool",
      "var/tmp"
    ]

    # No Copy On Write for SQL databases and libvirt virtual disks to
    # minimize performance impact
    NO_COW_SUBVOL_PATHS = [
      "var/lib/libvirt/images",
      "var/lib/mariadb",
      "var/lib/mysql",
      "var/lib/pgsql"
    ]

    def initialize(path, copy_on_write: true, archs: nil)
      @path = path
      @copy_on_write = copy_on_write
      @archs = archs
    end

    def to_s
      text = "PlannedSubvol #{@path}"
      text += " (NoCOW)" unless @copy_on_write
      text += " (archs: #{@archs})" if arch_specific?
      text
    end

    def arch_specific?
      !archs.nil?
    end

    def cow?
      @copy_on_write
    end

    def no_cow?
      !@copy_on_write
    end

    # Comparison operator for sorting
    #
    def <=>(other)
      path <=> other.path
    end

    # Check if this subvolume should be used for the current architecture.
    # A subvolume is used if its archs contain the current arch.
    # It is not used if its archs contain the current arch negated
    # (e.g. "!ppc").
    #
    # @return [Boolean] true if this subvolume matches the current architecture
    #
    def current_arch?
      matches_arch? { |arch| Yast::Arch.respond_to?(arch.to_sym) && Yast::Arch.send(arch.to_sym) }
    end

    # Check if this subvolume should be used for an architecture.
    #
    # If a block is given, the block is called as the matcher with the
    # architecture to be tested as its argument.
    #
    # If no block is given (and only then), the 'target_arch' parameter is
    # used to check against.
    #
    # @return [Boolean] true if this subvolume matches
    #
    def matches_arch?(target_arch = nil, &block)
      return true unless arch_specific?
      use_subvol = false
      archs.each do |a|
        arch = a.dup
        negate = arch.start_with?("!")
        arch[0] = "" if negate # remove leading "!"
        match = block_given? ? block.call(arch) : arch == target_arch
        if match && negate
          log.info("Not using #{self} for explicitly excluded arch #{arch}")
          return false
        end
        use_subvol ||= match
      end
      log.info("Using arch specific #{self}: #{use_subvol}")
      use_subvol
    end

    # Create the subvolume as child of 'parent_subvol'.
    #
    # @param parent_subvol [::Storage::BtrfsSubvol]
    # @param default_subvol [String] "@" or ""
    # @param mount_prefix [String]
    #
    # @return [::Storage::BtrfsSubvol]
    #
    def create_subvol(parent_subvol, default_subvol, mount_prefix)
      name = @path
      name = default_subvol + "/" + path unless default_subvol.empty?
      subvol = parent_subvol.create_btrfs_subvolume(name)
      subvol.nocow = true if no_cow?
      subvol.mountpoint = mount_prefix + @path
      subvol
    end

    # Factory method: Create one PlannedSubvol from XML data stored as a map.
    #
    # @return [PlannedSubvol] or nil if error
    #
    def self.create_from_xml(xml)
      return nil unless xml && xml.key?("path")
      path = xml["path"]
      cow = true
      if xml.key?("copy_on_write")
        cow = xml["copy_on_write"]
      end
      archs = nil
      if xml.key?("archs")
        archs = xml["archs"].gsub(/\s+/, "").split(",")
      end
      planned_subvol = PlannedSubvol.new(path, copy_on_write: cow, archs: archs)
      log.info("Creating from XML: #{planned_subvol}")
      planned_subvol
    end

    # Create a list of PlannedSubvols from the <subvolumes> part of
    # control.xml. The map may be empty if there is a <subvolumes> section, but
    # that section is empty.
    #
    # This function does not do much error handling or reporting; it is assumed
    # that control.xml is validated against its schema.
    #
    # @param subvolumes_xml list of XML <subvolume> entries
    # @return PlannedSubvolumes map or nil
    #
    def self.create_from_control_xml(subvolumes_xml)
      return nil if subvolumes_xml.nil?
      return nil unless subvolumes_xml.respond_to?(:map)

      all_subvols = subvolumes_xml.map { |xml| PlannedSubvol.create_from_xml(xml) }
      all_subvols.compact! # Remove nil subvols due to XML parse errors
      relevant_subvols = all_subvols.select { |s| s.current_arch? }
      relevant_subvols.sort
    end

    # Create a fallback list of PlannedSubvols. This is useful if nothing is
    # specified in the control.xml file.
    #
    # @return List<PlannedSubvol>
    #
    # rubocop:disable Metrics/LineLength
    def self.fallback_list
      planned_subvols = []
      COW_SUBVOL_PATHS.each    { |path| planned_subvols << PlannedSubvol.new(path) }
      NO_COW_SUBVOL_PATHS.each { |path| planned_subvols << PlannedSubvol.new(path, copy_on_write: false) }
      planned_subvols << PlannedSubvol.new("boot/grub2/i386-pc",          archs: ["i386", "x86_64"])
      planned_subvols << PlannedSubvol.new("boot/grub2/x86_64-efi",       archs: ["x86_64"])
      planned_subvols << PlannedSubvol.new("boot/grub2/powerpc-ieee1275", archs: ["ppc", "!board_powernv"])
      planned_subvols << PlannedSubvol.new("boot/grub2/s390x-emu",        archs: ["s390"])
      planned_subvols.select { |s| s.current_arch? }.sort
    end
    # rubocop:enable Metrics/LineLength
  end
end
