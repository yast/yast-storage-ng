#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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
require "set"

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
    # Any map value may be a string, a list of strings, or 'nil'.
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
        UF_LVM:           "lvm2",
        # Btrfs needs e2fsprogs for 'lsattr' and 'chattr' to check for CoW
        UF_BTRFS:         ["btrfsprogs", "e2fsprogs"],
        UF_SNAPSHOTS:     "snapper",

        # RAID technologies and related
        UF_DM:            "device-mapper",
        UF_DMMULTIPATH:   ["device-mapper", "multipath-tools"],
        UF_DMRAID:        ["device-mapper", "dmraid"],
        UF_MD:            "mdadm",
        UF_MDPART:        "mdadm",

        # Other filesystems
        UF_EXT2:          "e2fsprogs",
        UF_EXT3:          "e2fsprogs",
        UF_EXT4:          "e2fsprogs",
        UF_XFS:           "xfsprogs",
        UF_REISERFS:      "reiserfs",
        UF_NFS:           "nfs-client",
        UF_NFS4:          "nfs-client",
        UF_NTFS:          ["ntfs-3g", "ntfsprogs"],
        UF_VFAT:          "dosfstools",

        # Crypto technologies
        UF_LUKS:          "cryptsetup",
        UF_CRYPT_TWOFISH: "cryptsetup",

        # Data transport methods
        UF_ISCSI:         "open-iscsi",
        UF_FCOE:          "fcoe-utils",
        UF_FC:            nil,

        # Other
        UF_QUOTA:         "quota",
        UF_BCACHE:        "bcache-tools",

        # FIXME: This is not related to the devicegraph, so libstorage doesn't
        # return it yet. The "efibootmgr" package is available in the inst-sys
        # anyway, and it is only needed in very exotic cases in the installed
        # system: Only if the user wishes to delete a partition (e.g. his
        # Windows partition) the EFI bootloader could boot from. Adding a
        # partition to it is handled by yast-bootloader in the inst-sys.
        UF_EFIBOOT:       "efibootmgr"
      }
    # configurable part ends here
    #======================================================================

    #
    #----------------------------------------------------------------------
    #

    def initialize(devicegraph)
      @devicegraph = devicegraph
    end

    # Collect storage features and return a feature list
    # (a list containing :UF_xy symbols). The list may be empty.
    #
    # @return [Array<Symbol>] feature list
    #
    def collect_features
      return [] if @devicegraph.nil?
      feature_bits = @devicegraph.used_features
      features_dumped = false
      features = []

      FEATURE_PACKAGES.each_key do |feature|
        begin
          mask = bitmask(feature)
          if (feature_bits & mask) == mask
            features << feature
            log.info("Detected feature #{feature}")
          end
        rescue NameError => err
          if err.name == feature
            log.warn("WARNING: Packages configured for unknown feature :#{feature}")
            log.info("Features known to libstorage: #{libstorage_features.sort}") unless features_dumped
            features_dumped = true
          else
            log.error("Error: #{err}")
            raise
          end
        end
      end

      log.info("Storage features used: #{features}")
      features
    end

    # Return a list of software packages required for the storage features in
    # 'features'.
    #
    # @param [Array<Symbol>] feature list
    # @return [Array<Symbol>] package list
    #
    def self.packages_for(features)
      feature_packages = Set.new

      features.each do |feature|
        pkg = FEATURE_PACKAGES[feature]
        next unless pkg
        log.info("Feature #{feature} requires pkg #{pkg}")
        if pkg.respond_to?(:each)
          feature_packages.merge(pkg)
        else
          feature_packages << pkg
        end
      end

      log.info("Storage feature packages: #{feature_packages.to_a}")
      feature_packages.to_a
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
    # @param  [Symbol] UF_* feature
    # @return [Fixnum] bitmask for that feature
    #
    def bitmask(feature)
      ::Storage.const_get(feature)
    end
  end
end

# if used standalone, do a minimalistic test case (invoke with "sudo"!)

if $PROGRAM_NAME == __FILE__ # Called direcly as standalone command? (not via rspec or require)
  devicegraph = Y2Storage::StorageManager.instance.probed
  used_features = Y2Storage::UsedStorageFeatures.new(devicegraph)
  features = used_features.collect_features
  print("Used storage features: #{features}\n")
  pkg_list = used_features.feature_packages
  print("Needed packages: #{pkg_list}\n")
end
