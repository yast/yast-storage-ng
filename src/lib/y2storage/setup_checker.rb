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
require "y2storage/blk_device"
require "y2storage/setup_error"
require "y2storage/boot_requirements_checker"
require "y2storage/proposal_settings"

# This 'import' is necessary to load the control file (/etc/YaST/control.xml)
# when running in an installed system. During installation, this module
# is imported by WorkflowManager.
Yast.import "ProductControl"

module Y2Storage
  # Class to check whether a setup (devicegraph) fulfills the storage requirements
  #
  # The storage requirements are the set of necessary volumes to properly boot and
  # run the system. Boot checkings are actually performed by class BootRequirementsChecker,
  # and needed volumes to run the system are read from control file (control.xml).
  #
  # @example
  #   checker = SetupChecker.new(devicegraph)
  #   checker.valid? #=> true
  class SetupChecker
    # @return [Devicegraph]
    attr_reader :devicegraph

    # Constructor
    #
    # @param devicegraph [Devicegraph] setup to check
    def initialize(devicegraph)
      @devicegraph = devicegraph
    end

    # Whether the current setup fulfills the storage requirements
    #
    # @return [Boolean]
    def valid?
      errors.empty? && warnings.empty?
    end

    # Whether the system contain fatal errors preventing to continue
    #
    # @return [Array<SetupError>]
    def errors
      boot_requirements_checker.errors
    end

    # All storage warnings detected in the setup, for example, when a /boot/efi partition
    # is missing in a UEFI system, or missing separate /boot.
    #
    # @see SetupError
    #
    # @return [Array<SetupError>]
    def warnings
      boot_warnings + product_warnings
    end

    # All boot errors detected in the setup
    #
    # @return [Array<SetupError>]
    #
    # @see BootRequirementsChecker#errors
    def boot_warnings
      @boot_warnings ||= boot_requirements_checker.warnings
    end

    # All product warnings detected in the setup
    #
    # This checks that all mandatory volumes specified in control file are present
    # in the system.
    #
    # @return [Array<SetupError>]
    def product_warnings
      @product_warnings ||= missing_product_volumes.map { |v| SetupError.new(missing_volume: v) }
    end

  private

    # Mandatory product volumes that are not present in the current setup
    #
    # @see #product_volumes
    #
    # @return [Array<VolumeSpecification>]
    def missing_product_volumes
      product_volumes.select { |v| missing?(v) }
    end

    # Mandatory product volumes for a valid storage setup
    #
    # @note This volumes are obtained from the control file (control.xml) and only
    #   mandatory volumes are taken into account.
    #
    # @see ProposalSettings#volumes
    #
    # @return [Array<VolumeSpecification>]
    def product_volumes
      # ProposalSettings#volumes is initialized to nil when using old settings format
      # because this attribute does not exist with old format
      volumes = ProposalSettings.new_for_current_product.volumes || []
      volumes.select { |v| mandatory?(v) }
    end

    # Whether a volume is mandatory, that is, the volume is proposed to be created
    # and cannot be deactivated.
    #
    # @param volume [VolumeSpecification]
    # @return [Boolean] true if the volume is mandatory; false otherwise.
    def mandatory?(volume)
      volume.proposed? && !volume.proposed_configurable?
    end

    # Whether a volume is missing in the current setup
    #
    # @see BlkDevice#match_volume?
    #
    # @param volume [VolumeSpecification]
    # @return [Boolean] true if the volume is missing; false otherwise.
    def missing?(volume)
      BlkDevice.all(devicegraph).none? { |d| d.match_volume?(volume) }
    end

    def boot_requirements_checker
      @boot_requirements_checker ||= BootRequirementsChecker.new(devicegraph)
    end
  end
end
