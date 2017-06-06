#!/usr/bin/env ruby
#
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
require "y2storage/used_storage_features"

Yast.import "Package"
Yast.import "PackagesProposal"
Yast.import "Mode"
Yast.import "Report"
Yast.import "Popup"
Yast.import "Label"

module Y2Storage
  #
  # Class that takes care of packages in the storage context: Add
  # storage-related packages to the set of packages to install during
  # installation, install small sets of packages in the installed system (for
  # the expert partitioner) as needed.
  #
  class PackageHandler
    include Yast::Logger
    include Yast::I18n

    attr_reader :pkg_list

    PROPOSAL_ID = "storage_proposal"

    def initialize
      textdomain("storage-ng")
      reset
    end

    # Clear the package list
    #
    def reset
      @pkg_list = []
    end

    # Add a number of packages to the list of packages to be installed
    #
    # @param  pkg_list [Array<String>] package names
    # @return [Array<String>] new package list (may contain duplicates)
    def add_packages(pkg_list)
      @pkg_list.concat(pkg_list)
    end

    # Add the packages for the storage features in 'devicegraph' to the list of
    # packages to be installed
    #
    # @param [::Storage::devicegraph] devicegraph to obtain the features from
    # @return [Array<String>] new package list (may contain duplicates)
    #
    def add_feature_packages(devicegraph)
      used_features = UsedStorageFeatures.new(devicegraph)
      packages = used_features.feature_packages
      packages = packages.delete_if { |pkg| unavailable_optional_package?(pkg) }
      add_packages(packages)
    end

    # Check if a package is an optional package that is unavailable.
    # See also bsc#1039830
    #
    # @param package [String] package name
    # @return [Boolean] true if package is optional and unavailable,
    #                   false if not optional or if available.
    def unavailable_optional_package?(package)
      return false unless UsedStorageFeatures::OPTIONAL_PACKAGES.include?(package)
      return false if Yast::Package.Available(package)
      log.warn("WARNING: Skipping unavailable filesystem support package #{package}")
      true
    end

    # Start a package dependency resolver run
    #
    def solve
      Yast::Pkg.PkgSolve(true)
    end

    # Commit the changes depending on the current mode: During OS installation,
    # mark the package list for installation. In the installed system, install
    # them immediately.
    #
    def commit
      if Yast::Mode.installation
        set_proposal_packages
      else
        install
      end
    end

    # Execute package installation. This will install the stored package list
    # immediately, so it is not advisable to do this during the OS
    # installation. In the latter case, use 'set_proposal_packages' instead.
    #
    # @return true on success, false on error
    #
    def install
      compact
      return if @pkg_list.empty?
      log.info("Installing #{pkg_list}")
      success = Yast::Package.DoInstall(@pkg_list)
      if !success
        log.error("ERROR: Some packages could not be installed")
        install_error_popup
      end
      success
    end

    # Set the proposal packages for storage. This marks the packages for
    # installation; it does not install them yet.
    #
    def set_proposal_packages
      compact
      return if @pkg_list.empty?
      log.info("Marking #{pkg_list} for installation")
      if !Yast::PackagesProposal.SetResolvables(PROPOSAL_ID, :package, @pkg_list)
        log.error("PackagesProposal::SetResolvables() for #{pkg_list} failed")
        set_resolvables_error_popup
      end
      solve
      nil
    end

    # Remove duplicates from the package list and those packages that are
    # already installed.
    #
    # @return [Array<String>] compacted list
    #
    def compact
      @pkg_list.uniq!
      @pkg_list = @pkg_list.delete_if { |pkg| Yast::Package.Installed(pkg) }
    end

  private

    # Post an error popup after installing some packages failed
    #
    def install_error_popup
      # This message is not very informative, but the Package module does
      # not provide any more information.
      #
      # TRANSLATORS: error popup
      Yast::Report.Error(_("Installing required packages failed."))
    end

    # Post an error popup after SetResolvables failed
    #
    def set_resolvables_error_popup
      pkg_list = @pkg_list.join(", ")
      # TRANSLATORS: error popup. %s is the list of affected packages.
      Yast::Report.Error(_("Adding the following packages failed: %s") % pkg_list)
    end
  end
end
