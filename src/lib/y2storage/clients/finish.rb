# Copyright (c) [2018-2019] SUSE LLC
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
require "installation/finish_client"
require "y2storage/used_filesystems"

module Y2Storage
  module Clients
    # Finish client for storage-related tasks
    class Finish < ::Installation::FinishClient
      # Constructor
      def initialize
        super

        textdomain "storage"
        Yast.import "Service"
      end

      protected

      # Title to tell the user what is happening
      # @return [String]
      def title
        # progress step title
        _("Saving file system configuration...")
      end

      # Performs the final actions in the target system
      def write
        enable_multipath
        update_sysconfig
        finish_devices
        enable_tpm2
        true
      end

      # Enables multipathd in the targed system, if it is required.
      def enable_multipath
        return unless multipath?

        log.info "Enabling multipathd in the target system"
        Yast::Service.Enable("multipathd")
      end

      # Enabe TPM2, if it is required
      def enable_tpm2
        log.info ("enable_tpm2")
        puts("xxxxxxxxxxxxxxxxxxxxx33")
        puts(StorageManager.instance.proposal.settings.class)
        puts(StorageManager.instance.proposal.settings.use_encryption)
        puts(StorageManager.instance.proposal.settings.encryption_password)
        puts(StorageManager.instance.proposal.settings.encryption_use_tpm2)
        puts ("eeeeeeeeeeeeeeeeeeeeee")  
      end

      # Updates sysconfig file (/etc/sysconfig/storage) with current values
      # at StorageManager and other locations.
      #
      # Since the sysconfig file is not copied from the inst-sys to the target
      # each variable needs it own handling.
      #
      # @note This updates the sysconfig file in the target system.
      def update_sysconfig
        StorageManager.instance.configuration.update_sysconfig
        Y2Storage::UsedFilesystems.new(Y2Storage::StorageManager.instance.staging).write
      end

      # Checks whether multipath will be used in the target system
      # @return [Boolean]
      def multipath?
        staging.used_features.map(&:id).include?(:UF_MULTIPATH)
      end

      # Executes the finish installation actions for all devices
      def finish_devices
        staging.finish_installation
      end

      # Staging devicegraph
      #
      # @return [Devicegraph]
      def staging
        StorageManager.instance.staging
      end
    end
  end
end
