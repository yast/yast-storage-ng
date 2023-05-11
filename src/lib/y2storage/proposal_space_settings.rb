# Copyright (c) [2023] SUSE LLC
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
require "y2storage/equal_by_instance_variables"

module Y2Storage
  # Class to encapsulate all the GuidedProposal settings related to the process of making space
  # to allocate the new operating system
  class ProposalSpaceSettings
    include EqualByInstanceVariables

    # @see .delete_modes
    # TODO: enum?
    DELETE_MODES = [:none, :all, :ondemand].freeze
    private_constant :DELETE_MODES

    # @return [Array<String>] list of possible delete strategies
    def self.delete_modes
      DELETE_MODES
    end

    # @return [Boolean] whether to resize Windows systems if needed
    attr_accessor :resize_windows

    # What to do regarding removal of existing partitions hosting a Windows system.
    #
    # Options:
    #
    # * :none Never delete a Windows partition.
    # * :ondemand Delete Windows partitions as needed by the proposal.
    # * :all Delete all Windows partitions, even if not needed.
    #
    # @raise ArgumentError if any other value is assigned
    #
    # @return [Symbol]
    attr_accessor :windows_delete_mode

    # @return [Symbol] what to do regarding removal of existing Linux
    #   partitions. See {DiskAnalyzer} for the definition of "Linux partitions".
    #   @see #windows_delete_mode for the possible values and exceptions
    attr_accessor :linux_delete_mode

    # @return [Symbol] what to do regarding removal of existing partitions that
    #   don't fit in #windows_delete_mode or #linux_delete_mode.
    #   @see #windows_delete_mode for the possible values and exceptions
    attr_accessor :other_delete_mode

    # Whether the delete mode of the partitions and the resize option for windows can be
    # configured. When this option is set to `false`, the {#windows_delete_mode}, {#linux_delete_mode},
    # {#other_delete_mode} and {#resize_windows} options cannot be modified by the user.
    #
    # @return [Boolean]
    attr_accessor :delete_resize_configurable

    # Whether the settings disable deletion of a given type of partitions
    #
    # @see #windows_delete_mode
    # @see #linux_delete_mode
    # @see #other_delete_mode
    #
    # @param type [#to_s] :linux, :windows or :other
    # @return [Boolean]
    def delete_forbidden(type)
      send(:"#{type}_delete_mode") == :none
    end

    alias_method :delete_forbidden?, :delete_forbidden

    # Whether the settings enforce deletion of a given type of partitions
    #
    # @see #windows_delete_mode
    # @see #linux_delete_mode
    # @see #other_delete_mode
    #
    # @param type [#to_s] :linux, :windows or :other
    # @return [Boolean]
    def delete_forced(type)
      send(:"#{type}_delete_mode") == :all
    end

    alias_method :delete_forced?, :delete_forced
  end
end
