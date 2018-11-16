# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2storage/proposal"
require "y2storage/exceptions"

module Y2Storage
  # Class to calculate the initial storage proposal
  #
  # @see GuidedProposal
  class InitialGuidedProposal < GuidedProposal
    # Constructor
    #
    # @see GuidedProposal#initialize
    #
    # @param settings [ProposalSettings]
    # @param devicegraph [Devicegraph]
    # @param disk_analyzer [DiskAnalyzer]
    def initialize(settings: nil, devicegraph: nil, disk_analyzer: nil)
      super

      @initial_settings = Yast.deep_copy(self.settings)
    end

  private

    # Initial settings
    #
    # The initial proposal could try with different settings over each candidate device.
    # This initial settings allows to restore the settings to its original version when
    # switching to a new candidate device.
    #
    # @return [ProposalSettings]
    attr_reader :initial_settings

    # @return [Proposal::SettingsGenerator::Base]
    attr_reader :settings_generator

    # Tries to perform the initial proposal
    #
    # @see GuidedProposal#calculate_proposal
    #
    # The initial proposal will perform several attempts until a valid proposal is generated.
    # First, the proposal is tried over each individual candidate device. If a proposal was
    # not possible for any of the candidate devices, a last attempt is performed taking into
    # account all the candidate devices together.
    #
    # Moreover, several attempts are performed for each candidate device. First, a proposal
    # is calculated with the initial settings, and if it did not success, a new attempt is
    # tried with different settings. The new settings are a reduced version of the settings
    # used in the previous attempt. For example, the separate home or the snapshots can be
    # disabled for the new attempt.
    #
    # Finally, when the proposal is calculated with all the candidate devices together, several
    # attempts are performed considering each candidate device as possible root device.
    #
    # @raise [Error, NoDiskSpaceError] when the proposal cannot be calculated
    #
    # @return [true]
    def try_proposal
      try_with_each_candidate_group
    end

    # Tries to calculate a proposal for each group of candidate devices
    #
    # It stops once a valid proposal is calculated.
    #
    # @see #groups_of_candidate_devices
    #
    # @raise [Error, NoDiskSpaceError] when the proposal cannot be calculated
    #
    # @return [true]
    def try_with_each_candidate_group
      error = default_proposal_error

      groups_of_candidate_devices.each do |candidate_group|
        reset_settings
        settings.candidate_devices = candidate_group

        begin
          return try_with_different_settings
        rescue Error => error
          next
        end
      end

      raise error
    end

    # Tries to calculate a proposal by using different settings for each attempt
    #
    # When a proposal is not possible, it tries a new attempt after disabling some
    # properties in the settings, for example, the separate home or the snaphots.
    #
    # It stops once a valid proposal is calculated.
    #
    # @see #create_settings_generator
    #
    # @raise [Error, NoDiskSpaceError] when the proposal cannot be calculated
    #
    # @return [true]
    def try_with_different_settings
      error = default_proposal_error

      create_settings_generator

      loop do
        break unless assign_next_settings

        begin
          return try_with_different_root_devices
        rescue Error => error
          next
        end
      end

      raise error
    end

    # Tries to calculate a proposal by using different root devices
    #
    # When a proposal is not possible, it tries a new attempt after switching the root device.
    #
    # It stops once a valid proposal is calculated.
    #
    # @see #candidate_roots
    #
    # @raise [Error, NoDiskSpaceError] when the proposal cannot be calculated
    #
    # @return [true]
    def try_with_different_root_devices
      error = default_proposal_error

      candidate_roots.each do |root_device|
        settings.root_device = root_device

        log.info "Trying to make a proposal with the following settings: #{settings}"

        begin
          return try_with_each_target_size
        rescue Error => error
          next
        end
      end

      raise error
    end

    # Resets the settings by assigning the initial settings
    #
    # @note The SpaceMaker object needs to be created again when the candidate
    #   devices have changed.
    def reset_settings
      self.space_maker = nil
      self.settings = Yast.deep_copy(initial_settings)
    end

    # Creates a generator of settings
    #
    # It is used to get the new settings to use for each proposal attempt.
    #
    # @see Proposal::SettingsGenerator::Legacy
    # @see Proposal::SettingsGenerator::Ng
    #
    # @return [Proposal::SettingsGenerator::Base]
    def create_settings_generator
      @settings_generator = if settings.ng_format?
        Proposal::SettingsGenerator::Ng.new(settings)
      else
        Proposal::SettingsGenerator::Legacy.new(settings)
      end
    end

    # Assigns the settings to use for the current proposal attempt
    #
    # It also saves the performed adjustments.
    #
    # @return [Boolean] true if the next settings can be generated; false otherwise.
    def assign_next_settings
      settings = settings_generator.next_settings
      return false if settings.nil?

      self.settings = settings
      self.auto_settings_adjustment = settings_generator.adjustments

      true
    end

    # Candidate devices grouped for different proposal attempts
    #
    # Different proposal attempts are performed by using different sets of candidate devices.
    # First, each candidate device is used individually, and if no proposal was possible with
    # any individual disk, a last attempt is done by using all available candidate devices.
    #
    # @example
    #
    #   settings.candidate_devices #=> ["/dev/sda", "/dev/sdb"]
    #   settings.groups_of_candidate_devices #=> [["/dev/sda"], ["/dev/sdb"], ["/dev/sda", "/dev/sdb"]]
    #
    # @return [Array<Array<String>>]
    def groups_of_candidate_devices
      candidates = candidate_devices

      candidates.zip.append(candidates).uniq
    end

    # Sorted list of disks to be tried as root device.
    #
    # If the current settings already specify a root_device, the list will contain only that one.
    #
    # Otherwise, it will contain all the candidate devices, sorted from bigger to smaller disk size.
    #
    # @return [Array<String>]
    def candidate_roots
      return [settings.root_device] if settings.root_device

      disk_names = settings.candidate_devices

      candidates = disk_names.map { |n| initial_devicegraph.find_by_name(n) }.compact
      candidates = candidates.sort_by(&:size).reverse
      candidates.map(&:name)
    end
  end
end
