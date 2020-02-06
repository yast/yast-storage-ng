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
require "y2storage"

module Y2Storage
  #
  # Class that collects information about which storage features are used
  # in the current target machine's storage setup so add-on packages can be
  # marked for installation as needed.
  #
  # Usage:
  #
  #   # Create or obtain a device graph, e.g. with
  #   devicegraph = Y2Storage::StorageManager.instance.probed
  #
  #   used_features = Y2Storage::UsedStorageFeatures.new(devicegraph)
  #   pkg_list = used_features.feature_packages
  #
  class UsedStorageFeatures
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
        # Btrfs needs e2fsprogs for 'lsattr' and 'chattr' to check for CoW
        UF_BTRFS:            ["btrfsprogs", "e2fsprogs"],
        UF_SNAPSHOTS:        "snapper",

        # RAID technologies and related
        UF_DM:               "device-mapper",
        UF_MULTIPATH:        ["device-mapper", "multipath-tools"],
        UF_DMRAID:           ["device-mapper", "dmraid"],
        UF_MDRAID:           "mdadm",

        # Other filesystems
        UF_EXT2:             "e2fsprogs",
        UF_EXT3:             "e2fsprogs",
        UF_EXT4:             "e2fsprogs",
        UF_XFS:              "xfsprogs",
        UF_REISERFS:         "reiserfs",
        UF_NFS:              "nfs-client",
        UF_NTFS:             ["ntfs-3g", "ntfsprogs"],
        UF_VFAT:             "dosfstools",

        # Crypto technologies
        UF_LUKS:             "cryptsetup",
        UF_PLAIN_ENCRYPTION: "cryptsetup",

        # Data transport methods
        UF_ISCSI:            "open-iscsi",
        UF_FCOE:             "fcoe-utils",
        UF_FC:               [],

        # Other
        UF_QUOTA:            "quota",
        UF_BCACHE:           "bcache-tools",

        # FIXME: This is not related to the devicegraph, so libstorage doesn't
        # return it yet. The "efibootmgr" package is available in the inst-sys
        # anyway, and it is only needed in very exotic cases in the installed
        # system: Only if the user wishes to delete a partition (e.g. his
        # Windows partition) the EFI bootloader could boot from. Adding a
        # partition to it is handled by yast-bootloader in the inst-sys.
        UF_EFIBOOT:          "efibootmgr",
        UF_UDF:              "udftools"
      }

    # Storage-related packages that are nice to have, but not absolutely
    # required.
    #
    # SLES-12 for example (unlike SLED-12) does not come with NTFS packages,
    # so they cannot be installed. But there might already be an existing
    # NTFS Windows partition on the disk; don't throw an error pop-up in that
    # case, just log a warning (bsc#1039830).
    #
    OPTIONAL_PACKAGES = ["ntfs-3g", "ntfsprogs"]
    # configurable part ends here
    #======================================================================

    #
    #----------------------------------------------------------------------
    #

    # Initialize object.
    #
    # @param arg [Integer or ::Storage::Devicegraph] Either a integer with the feature
    #   bits or a devicegraph from which to get the feature bits.
    #
    def initialize(arg)
      @devicegraph = nil
      @used_features = nil
      if arg.is_a?(Integer)
        @used_features = arg
      else
        @devicegraph = arg
      end
    end

    # Calculate the feature bits.
    #
    # @return [Integer] Feature bits.
    #
    def calculate_feature_bits
      return 0 if @used_features.nil? && @devicegraph.nil?

      @devicegraph.nil? ? @used_features : @devicegraph.used_features
    end

    # Collect storage features and return a feature list
    # (a list containing :UF_xy symbols). The list may be empty.
    #
    # @return [Array<Symbol>] feature list
    #
    def collect_features
      feature_bits = calculate_feature_bits
      return [] if feature_bits == 0

      features_dumped = false
      features = []

      FEATURE_PACKAGES.each_key do |feature|

        mask = bitmask(feature)
        if (feature_bits & mask) == mask
          features << feature
          log.info("Detected feature #{feature}")
        end
      rescue NameError => e
        if e.name == feature
          log.warn("WARNING: Packages configured for unknown feature :#{feature}")
          log.info("Features known to libstorage: #{libstorage_features.sort}") unless features_dumped
          features_dumped = true
        else
          log.error("Error: #{e}")
          raise
        end

      end

      log.info("Storage features used: #{features}")
      features
    end

    # Return a list of software packages required for the storage features in
    # 'features'.
    #
    # @param features [Array<Symbol>] feature list
    # @return [Array<Symbol>] package list
    def self.packages_for(features)
      feature_packages = []

      features.each do |feature|
        next unless FEATURE_PACKAGES.key?(feature)

        required_packages = [FEATURE_PACKAGES.fetch(feature)].flatten

        log.info("Feature #{feature} requires #{required_packages}")

        feature_packages.concat(required_packages)
      end

      feature_packages.uniq!
      log.info("Storage feature packages: #{feature_packages}")

      feature_packages
    end

    # Return a list of software packages required for the storage features
    # currently in use by the internal devicegraph.
    #
    # @return [Array<Symbol>] package list
    #
    def feature_packages
      self.class.packages_for(collect_features)
    end

    # Return the list of storage features known to libstorage.
    # This uses introspection to find all constants starting with UF_
    # in the ::Storage (libstorage) namespace.
    #
    # @return [Array<Symbol>] feature list
    #
    def libstorage_features
      ::Storage.constants.select { |c| c.to_s.start_with?("UF_") }
    end

    # Return the bitmask for a storage feature. This looks up a constant in the
    # ::Storage (libstorage) namespace with that name (one of the enum values
    # in UsedFeatures.h). If there is no constant with that name (i.e., the
    # feature is unknown to libstorage), this will throw a NameError.
    #
    # @param  feature [Symbol] UF_* feature
    # @return [Integer] bitmask for that feature
    #
    def bitmask(feature)
      ::Storage.const_get(feature)
    end

    # Check if a storage-related package is an optional one, i.e. installation
    # can safely continue without it.
    #
    # @param package [String] package name
    # @return [Boolean] true if this is an optional package, false otherwise
    #
    def self.optional_package?(package)
      UsedStorageFeatures::OPTIONAL_PACKAGES.include?(package)
    end
  end
end
