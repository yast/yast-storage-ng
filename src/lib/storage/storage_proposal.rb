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
require_relative "./disk_analyzer"
require_relative "./space_maker"
require_relative "./partition_creator"
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

      DEFAULT_SWAP_SIZE = DiskSize.GiB(2)

      # Devicegraph names
      PROPOSAL_BASE = "proposal_base"
      PROPOSAL	    = "proposal"
      PROBED	    = "probed"
      STAGING	    = "staging"

      class NotEnoughDiskSpace < RuntimeError
      end

      def initialize
	@settings = ProposalSettings.new
	@proposal = nil	   # ::Storage::DeviceGraph
	@actions  = nil	   # ::Storage::ActionGraph
      end

      # Create a storage proposal.
      def propose
	StorageManager.start_probing
	prepare_devicegraphs

	boot_requirements_checker = BootRequirementsChecker.new(@settings)
	@volumes = boot_requirements_checker.needed_partitions
	@volumes += standard_volumes

	disk_analyzer = DiskAnalyzer.new
	disk_analyzer.analyze

	begin
	  space_maker = provide_space(disk_analyzer)
	  create_partitions(space_maker)
	  proposal_to_staging
	  action_text = proposal_text
	rescue NotEnoughDiskSpace => ex
	  action_text = "No proposal possible."
	  log.warn(action_text)
	  reset_proposal
	end

	log.info("Actions:\n#{action_text}\n")
	print("\nActions:\n\n#{action_text}\n")
      end

      # Provide free disk space in the proposal devicegraph to fit the volumes
      # in. Create a SpaceMaker and try those approaches until there is enough
      # free space:
      #
      # - space_maker.find_space     for space_maker.total_desired_sizes
      # - space_maker.resize_windows for space_maker.total_desired_sizes
      # - space_maker.make_space     for space_maker.total_desired_sizes
      # - space_maker.make_space     for space_maker.total_sizes(:min_size)
      #
      # If all that fails, a NotEnoughDiskSpace exception is raised.
      #
      # @param disk_analyzer [DiskAnalyzer]
      #
      # @return [SpaceMaker]
      #
      # Use the returned SpaceMaker to find out what strategy was used and the
      # free space that is now available.
      #
      def provide_space(disk_analyzer)
	space_maker = SpaceMaker.new(settings: @settings,
				     volumes:  @volumes,
				     candidate_disks:	 disk_analyzer.candidate_disks,
				     linux_partitions:	 disk_analyzer.linux_partitions,
				     windows_partitions: disk_analyzer.windows_partitions,
				     devicegraph: @proposal)
        # Try with desired sizes
        success = space_maker.provide_space(:find_space,     :desired) ||
	          space_maker.provide_space(:resize_windows, :desired) ||
	          space_maker.provide_space(:make_space,     :desired)

        if !success
          # Not enough space for desired sizes - try again with minimum size
          log.info("Resetting proposal")
          reset_proposal # Restore any previously deleted partitions in the proposal graph
	  raise NotEnoughDiskSpace unless space_maker.provide_space(:make_space, :min_size)
        end

	log.info("Found #{space_maker.total_free_size} with strategy \"#{space_maker.strategy}\"")
	space_maker
      end

      # Create partitions according to the strategy in 'space_maker', using the
      # free space in the space_maker.
      #
      # @param space_maker [SpaceMaker]
      #
      def create_partitions(space_maker)
	  partition_creator = PartitionCreator.new(settings:	@settings,
						   devicegraph: @proposal,
                                                   space_maker: space_maker)
	  partition_creator.create_partitions(@volumes, space_maker.strategy)
      end

      # Return the textual description of the actions necessary to transform
      # the probed devicegraph into the staging devicegraph.
      #
      def proposal_text
	return "No storage proposal possible" unless @actions
	@actions.commit_actions_as_strings.to_a.join("\n")
      end

      # Reset the proposal devicegraph (PROPOSAL) to PROPOSAL_BASE.
      #
      def reset_proposal
	log.debug("Resetting proposal devicegraph")
	storage = StorageManager.instance
	storage.remove_devicegraph(PROPOSAL) if storage.exist_devicegraph(PROPOSAL)
	@proposal = storage.copy_devicegraph(PROPOSAL_BASE, PROPOSAL)
	@actions  = nil
      end

      # Copy the PROPOSAL devicegraph to STAGING so actions can be calculated
      # or commited
      #
      def proposal_to_staging
	storage = StorageManager.instance
	storage.remove_devicegraph(STAGING) if storage.exist_devicegraph(STAGING)
	storage.copy_devicegraph(PROPOSAL, STAGING)
	@actions = storage.calculate_actiongraph
      end

      private

      # Prepare the devicegraphs we are working on:
      #
      # - PROBED. This contains the disks and partitions that were probed.
      #
      # - PROPOSAL_BASE. This starts as a copy of PROBED. If the user decides
      #	       in the UI to have some partitions removed or everything on a
      #	       disk deleted to make room for the Linux installation, those
      #	       partitions are already deleted here. This is the base for all
      #	       calculated proposals. If a proposal goes wrong and needs to be
      #	       reset internally, it will be reset to this state.
      #
      #	 - PROPOSAL. This is the working devicegraph for the proposal
      #	       calculations. If anything goes wrong, this might be reset (with
      #	       reset_proposal) to PROPOSAL_BASE at any time.
      #
      # If no PROPOSAL_BASE devicegraph exists yet, it will be copied from PROBED.
      #
      def prepare_devicegraphs
	storage = StorageManager.instance
	storage.copy_devicegraph(PROBED, PROPOSAL_BASE) unless storage.exist_devicegraph(PROPOSAL_BASE)
	reset_proposal
      end

      # Return an array of the standard volumes for the root and /home file
      # systems
      #
      # @return [Array [ProposalVolume]]
      #
      def standard_volumes
        volumes = []
        volumes << make_swap_vol
	root_vol = make_root_vol
	volumes << root_vol
	volumes << make_home_vol(root_vol.desired_size) if @settings.use_separate_home
	volumes
      end

      # Create the ProposalVolume data structure for the swap volume according
      # to the settings.
      def make_swap_vol
        swap_vol = ProposalVolume.new("swap", ::Storage::SWAP)
        swap_size = DEFAULT_SWAP_SIZE
        if @settings.enlarge_swap_for_suspend
          swap_size = ram_size
        end
        swap_vol.min_size     = swap_size
        swap_vol.max_size     = swap_size
        swap_vol.desired_size = swap_size
        swap_vol
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
        weight = @settings.root_space_percent
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
      def make_home_vol(root_vol_size)
	home_vol = ProposalVolume.new("/home", @settings.home_filesystem_type)
	home_vol.min_size = @settings.home_min_size
	home_vol.max_size = @settings.home_max_size
	weight = 100.0 - @settings.root_space_percent
	home_vol.desired_size = root_vol_size * (weight / @settings.root_space_percent)
	home_vol
      end

      # Return the total amount of RAM as DiskSize
      #
      # @return [DiskSize] current RAM size
      #
      def ram_size
        # FIXME use the .proc.meminfo agent and its MemTotal field
        #   mem_info_map = Convert.to_map(SCR.Read(path(".proc.meminfo")))
        # See old Partitions.rb: SwapSizeMb()

        DiskSize.GiB(8)
      end
    end
  end
end

# if used standalone, do a minimalistic test case

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  proposal = Yast::Storage::Proposal.new
  proposal.settings.root_filesystem_type = ::Storage::XFS
  proposal.settings.use_separate_home = true
  proposal.settings.btrfs_increase_percentage = 150.0
  proposal.propose
  # pp proposal
end
