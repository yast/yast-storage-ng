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
require "storage"
require_relative "./disk_size"
require_relative "./storage_manager"
require_relative "./proposal_settings"
require_relative "./proposal_volume"
require_relative "./boot_requirements_checker"
require_relative "./space_maker"
require "pp"

# This file can be invoked separately for minimal testing.
# Use 'sudo' if you do that since it will do hardware probing with libstorage.

module Yast
  module Storage
    #
    # Storage proposal for installation: Class that can suggest how to create
    # or change partitions for a Linux system installation based on available
    # storage devices (disks) and certain configuration parameters.
    #
    class Proposal
      include Yast::Logger

      attr_accessor :settings

      # devicegraph names
      PROPOSAL = "proposal"
      PROBED   = "probed"

      def initialize
        @settings = ProposalSettings.new
        @proposal = nil # ::Storage::DeviceGraph
        @disk_blacklist = []
        @disk_greylist  = []
      end

      # Create a storage proposal.
      def propose
        storage = StorageManager.instance # this will start probing in the first invocation
        storage.remove_devicegraph(PROPOSAL) if storage.exist_devicegraph(PROPOSAL)
        @proposal = storage.copy_devicegraph(PROBED, PROPOSAL)

        boot_requirements_checker = BootRequirementsChecker.new(@settings)
        @volumes = boot_requirements_checker.needed_partitions
        @volumes += standard_volumes
        pp @volumes

        space_maker = SpaceMaker.new(@volumes, @settings)
      end

      def proposal_text
        # TO DO
        "No disks found - no storage proposal possible"
      end

      private

      # Return an array of the standard volumes for the root and /home file
      # systems
      #
      # @return [Array [ProposalVolume]]
      #
      def standard_volumes
        volumes = [make_root_vol]
        volumes << make_home_vol if @settings.use_separate_home
        volumes
      end

      # Create the ProposalVolume data structure for the root volume according
      # to the settings.
      #
      # This does NOT create the partition yet, only the data structure.
      #
      def make_root_vol
        root_vol = ProposalVolume.new("/", @settings.root_filesystem_type)
        root_vol.min_size = @settings.root_base_size
        root_vol.max_size = @settings.root_max_size
        if root_vol.filesystem_type = ::Storage::BTRFS
          multiplicator = 1.0 + @settings.btrfs_increase_percentage / 100.0
          root_vol.min_size *= multiplicator
          root_vol.max_size *= multiplicator
        end
        root_vol.desired_size = root_vol.max_size
        root_vol
      end

      # Create the ProposalVolume data structure for the /home volume according
      # to the settings.
      #
      # This does NOT create the partition yet, only the data structure.
      #
      def make_home_vol
        home_vol = ProposalVolume.new("/home", @settings.home_filesystem_type)
        home_vol.min_size = @settings.home_min_size
        home_vol.max_size = @settings.home_max_size
        home_vol.desired_size = home_vol.max_size
        home_vol
      end
    end
  end
end

# if used standalone, do a minimalistic test case

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  proposal = Yast::Storage::Proposal.new
  proposal.settings.root_filesystem_type = ::Storage::XFS
  proposal.settings.use_separate_home = true
  proposal.propose
  # pp proposal
end
