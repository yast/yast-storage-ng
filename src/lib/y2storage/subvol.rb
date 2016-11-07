# encoding: utf-8

# Copyright (c) [2012-2016] Novell, Inc.
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
  # Backported from the old yast2-storage
  #
  # Sample usage:
  #
  #   xml = ProductFeatures.GetSection("partitioning")
  #   subvols = Subvol.create_from_control_xml(xml["subvolumes"]) || Subvol.fallback_list
  #   subvols.each { |s| log.info("Initial #{s}") }
  #
  class Subvol
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
      text = "Subvol #{@path}"
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
        if block_given?
          match = block.call(arch)
        else
          match = arch == target_arch
        end
        if match && negate
          log.info("Not using #{self} for explicitly excluded arch #{arch}")
          return false
        end
        use_subvol ||= match
      end
      log.info("Using arch specific #{self}: #{use_subvol}")
      use_subvol
    end

    # Factory method: Create one Subvol from XML data stored as a map.
    #
    # @return Subvol or nil if error
    #
    def self.create_from_xml(xml)
      return nil unless xml.key?("path")
      path = xml["path"]
      cow = true
      if xml.key?("copy_on_write")
        cow = xml["copy_on_write"]
      end
      archs = nil
      if xml.key?("archs")
        archs = xml["archs"].gsub(/\s+/, "").split(",")
      end
      subvol = Subvol.new(path, copy_on_write: cow, archs: archs)
      log.info("Creating from XML: #{subvol}")
      subvol
    end

    # Create a list of Subvols from the <subvolumes> part of control.xml.
    # The map may be empty if there is a <subvolumes> section, but it's empty.
    #
    # This function does not do much error handling or reporting; it is assumed
    # that control.xml is validated against its schema.
    #
    # @param subvolumes_xml list of XML <subvolume> entries
    # @return Subvolumes map or nil
    #
    def self.create_from_control_xml(subvolumes_xml)
      return nil if subvolumes_xml.nil?
      return nil unless subvolumes_xml.respond_to?(:map)

      all_subvols = subvolumes_xml.map { |xml| Subvol.create_from_xml(xml) }
      all_subvols.compact! # Remove nil subvols due to XML parse errors
      relevant_subvols = all_subvols.select { |s| s.current_arch? }
      relevant_subvols.sort
    end

    # Create a fallback list of Subvols. This is useful if nothing is
    # specified in the control.xml file.
    #
    # @return List<Subvol>
    #
    def self.fallback_list
      subvols = []
      COW_SUBVOL_PATHS.each    { |path| subvols << Subvol.new(path) }
      NO_COW_SUBVOL_PATHS.each { |path| subvols << Subvol.new(path, copy_on_write: false) }
      subvols << Subvol.new("boot/grub2/i386-pc",          archs: ["i386", "x86_64"])
      subvols << Subvol.new("boot/grub2/x86_64-efi",       archs: ["x86_64"])
      subvols << Subvol.new("boot/grub2/powerpc-ieee1275", archs: ["ppc", "!board_powernv"])
      subvols << Subvol.new("boot/grub2/s390x-emu",        archs: ["s390"])
      subvols.select { |s| s.current_arch? }.sort
    end
  end
end
