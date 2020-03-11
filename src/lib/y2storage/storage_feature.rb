# Copyright (c) [2016-2017,2019-2020] SUSE LLC
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
require "storage"

module Y2Storage
  #
  # Class representing the storage features defined by libstorage-ng
  #
  # In libstorage-ng each feature is represented by a bit-mask identified
  # by a constant with name UF_XXX (with XXX being the name of the feature).
  # A set of features is represented by a bit-field of those masks.
  #
  # Thus, one of those bit-fields is used to specify which features are
  # used in the current target machine's storage setup. Additionally, a similar
  # bit-field is used to report features that have been detected in the system
  # but that cannot be probed because some command in missing.
  #
  # This class adds object orientation of top of that, each instance of
  # StorageFeature represents a concrete feature and offers methods to know
  # which add-on packages would be needed so support that feature, so they
  # can be installed or marked for installation as needed.
  #
  class StorageFeature
    include Yast::Logger

    #======================================================================
    # Configurable part starts here
    #
    # Software packages required for storage features.
    # Any map value may be a string or a list of strings.
    #
    # Packages that are part of a minimal installation (e.g., "util-linux")
    # are not listed here.
    #
    # Those features correspond directly to the enum defined in
    # https://github.com/openSUSE/libstorage-ng/blob/master/storage/UsedFeatures.h
    #
    FEATURE_PACKAGES =
      {
        # SUSE standard technologies
        UF_LVM:              "lvm2",

        # RAID technologies and related
        UF_MULTIPATH:        ["device-mapper", "multipath-tools"],
        UF_DMRAID:           ["device-mapper", "dmraid"],
        UF_MDRAID:           "mdadm",

        # Btrfs needs e2fsprogs for 'lsattr' and 'chattr' to check for CoW
        UF_BTRFS:            ["btrfsprogs", "e2fsprogs"],

        # Other filesystems
        UF_EXT2:             "e2fsprogs",
        UF_EXT3:             "e2fsprogs",
        UF_EXT4:             "e2fsprogs",
        UF_XFS:              "xfsprogs",
        UF_REISERFS:         "reiserfs",
        UF_NFS:              "nfs-client",
        UF_NTFS:             ["ntfs-3g", "ntfsprogs"],
        UF_VFAT:             "dosfstools",
        UF_EXFAT:            "exfat-utils",
        UF_F2FS:             "f2fs-tools",
        UF_UDF:              "udftools",
        UF_JFS:              "jfsutils",
        UF_SWAP:             [],

        # Crypto technologies
        UF_LUKS:             "cryptsetup",
        UF_PLAIN_ENCRYPTION: "cryptsetup",
        UF_BITLOCKER:        [],

        # Data transport methods
        UF_ISCSI:            "open-iscsi",
        UF_FCOE:             "fcoe-utils",
        UF_FC:               [],
        UF_DASD:             [],

        # Other
        UF_QUOTA:            "quota",
        UF_BCACHE:           "bcache-tools",
        UF_SNAPSHOTS:        "snapper"
      }

    # Storage-related packages that are nice to have, but not absolutely
    # required.
    #
    # SLES-12 for example (unlike SLED-12) does not come with NTFS packages,
    # so they cannot be installed. But there might already be an existing
    # NTFS Windows partition on the disk; don't throw an error pop-up in that
    # case, just log a warning (bsc#1039830).
    #
    OPTIONAL_PACKAGES = ["ntfs-3g", "ntfsprogs", "exfat-utils", "f2fs-tools", "jfsutils"]
    # configurable part ends here
    #======================================================================

    # All known features
    #
    # @return [Array<StorageFeature>]
    def self.all
      @all ||= FEATURE_PACKAGES.map do |id, pkg_names|
        packages = Array(pkg_names).map do |pkg|
          Package.new(pkg, optional: OPTIONAL_PACKAGES.include?(pkg))
        end
        new(id, packages)
      end
    end

    # Constructor
    #
    # This looks up a constant in the ::Storage namespace to make sure the id
    # is known to libstorage-ng.
    #
    # @raise [NameError] if no constant for this feature is defined in libstorage-ng
    #
    # @param id [Symbol] see {#id}
    # @param packages [Array<Package>] see {#all_packages}
    def initialize(id, packages)
      @id = id
      @all_packages = packages

      # Raising a NameError exception as soon as possible (i.e. in the constructor)
      # is a good way to make sure we are in sync with libstorage-ng regarding
      # the definition of possible features
      @bitmask = ::Storage.const_get(id)
    end

    # Symbol representation of the feature
    #
    # It has the same form than the corresponding constant name in
    # libstorage-ng, eg. :UF_NTFS
    #
    # @return [Symbol]
    attr_reader :id

    alias_method :to_sym, :id

    # Whether the feature is included in the given bit-field
    #
    # @param bitfield [Integer]
    # @return [Boolean]
    def in_bitfield?(bitfield)
      (bitfield & bitmask) == bitmask
    end

    # Names of the packages that should be installed if the feature is going to
    # be used
    #
    # @return [Array<String>]
    def pkg_list
      packages.map(&:name)
    end

    private

    attr_reader :all_packages

    # Bitmask for a storage feature
    #
    # This looks up a constant in the ::Storage (libstorage-ng) namespace with
    # the id of the feature (one of the enum values in UsedFeatures.h).
    #
    # @return [Integer]
    attr_reader :bitmask

    # List of packages associated to the feature
    #
    # @return [Array<StorageFeature::Package>]
    def packages
      return @packages unless @packages.nil?

      unavailable, @packages = all_packages.partition(&:unavailable_optional?)
      if unavailable.any?
        log.warn("WARNING: Skipping unavailable filesystem support packages #{unavailable.map(&:name)}")
      end

      @packages
    end

    # Internal class to represent a package associated to a storage feature
    class Package
      Yast.import "Package"

      # Constructor
      #
      # @param name [String] see {#name}
      # @param optional [Boolean] see {#optional?}
      def initialize(name, optional: false)
        @name = name
        @optional = optional
      end

      # @return [String] name of the package
      attr_reader :name

      # Whether installation of the package can be skipped if the package is not
      # available
      #
      # See the comment in {StorageFeature::OPTIONAL_PACKAGES} for more details
      #
      # @return [Boolean]
      def optional?
        !!@optional
      end

      # Check if a package is an optional package that is unavailable.
      # See also bsc#1039830
      #
      # @return [Boolean] true if package is optional and unavailable,
      #                   false if not optional or if available.
      def unavailable_optional?
        optional? && !Yast::Package.Available(name)
      end
    end
  end
end
