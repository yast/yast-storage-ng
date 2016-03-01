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
require "storage/proposal"
require "storage/refined_devicegraph"

module Yast
  module Storage
    # Demo of the storage proposal for installation
    #
    # Client that can suggest how to create or change partitions for a Linux
    # system installation based on available storage devices (disks) and
    # certain configuration parameters.
    class ProposalDemoClient
      using RefinedDevicegraph
      include Yast::Logger

      attr_writer :verbose

      def initialize(verbose)
        @verbose  = verbose
      end

      # Create a storage proposal.
      def run
        begin
          proposal = Proposal.new(settings: settings)
          proposal.propose
          actions = proposal.devices.actiongraph

          action_text = actions_to_text(actions)
        rescue Proposal::NoDiskSpaceError
          action_text = "No proposal possible."
          log.warn(action_text)
        end

        print_volumes(proposal.volumes) if verbose?
        log.info("Actions:\n#{action_text}\n")
        print("\nActions:\n\n#{action_text}\n")
      end

      protected

      # Checks if verbose output is desired
      #
      # return [Boolean]
      def verbose?
        @verbose
      end

      # TODO: read this from somewhere
      def settings
        @settings ||= begin
          settings = Proposal::Settings.new
          # settings.root_max_size = DiskSize.unlimited
          # settings.root_filesystem_type = ::Storage::XFS
          # settings.btrfs_increase_percentage = 150.0
          settings.use_separate_home = true
          settings
        end
      end

      # Return the textual description of the actions necessary to transform
      # the probed devicegraph into the staging devicegraph.
      #
      def actions_to_text(actions)
        return "No storage proposal possible" unless actions
        actions.commit_actions_as_strings.to_a.join("\n")
      end

      # Print the volums to stdout.
      #
      def print_volumes(volumes)
        volumes.each do |vol|
          print("\nVolume \"#{vol.mount_point}\":\n")
          print("  min: #{vol.min_size};")
          print("  max: #{vol.max_size};")
          print("  desired: #{vol.desired_size};")
          print("  size: #{vol.size};")
          print("  weight: #{vol.weight};\n")
        end
        print("\n")
      end
    end
  end
end
