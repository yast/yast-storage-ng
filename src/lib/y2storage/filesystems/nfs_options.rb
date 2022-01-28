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

require "y2storage/filesystems/nfs_version"

module Y2Storage
  module Filesystems
    class NfsOptions
      attr_reader :options

      # Parse to an internal representation:
      # Simply split by commas, but "defaults" is represented by the empty list
      # @param [String] options a fstab option string
      # @return [Array<String>] of individual options
      def self.create_from_fstab(fstab_options)
        return new if fstab_options == "defaults"

        new(fstab_options.split(/[\s,]+/))
      end

      def initialize(options = [])
        @options = options
      end

      # Convert list of individual options to a fstab option string
      # @param [Array<String>] option_list list of individual options
      # @return [String] a fstab option string
      def to_fstab
        return "defaults" if options.empty?

        options.join(",")
      end

      def version
        option = version_option || ""

        value = option.split("=")[1]

        NfsVersion.new(value)
      end

      # @param version [Y2Storage::Filesystems::NfsVersion]
      def version=(version)
        # Cleanup minorversion, it should never be used
        options.delete_if { |o| o.start_with?("minorversion=") }

        # Cleanup surplus options
        option_to_keep = version.any? ? nil : version_option
        options.delete_if { |o| version_option?(o) && !o.equal?(option_to_keep) }

        return self if version.any?

        if option_to_keep
          option_to_keep.gsub!(/=.*$/, "=#{version.value}")
        else
          options << "nfsvers=#{version.value}"
        end

        self
      end

      # Checks whether some of the old options that used to work to configure
      # the NFS version (but do not longer work now) is used.
      #
      # Basically, this checks for the presence of minorversion
      #
      # @return [Boolean]
      def legacy?
        options.any? { |o| o.start_with?("minorversion=") }
      end

      private

      # Option used to set the NFS protocol version
      #
      # @param option_list [Array<String>]
      # @return [String, nil] contains the whole 'option=value' string
      def version_option
        # According to manual tests and documentation, none of the forms has higher precedence.
        # Use #reverse_each because in case of conflicting options, the latest one is used by mount
        options.reverse_each.find { |o| version_option?(o) }
      end

      # Checks if a given option is used to configure the NFS protocol version
      #
      # @param [String]
      # @return [Boolean]
      def version_option?(option)
        option.start_with?("nfsvers=", "vers=")
      end
    end
  end
end
