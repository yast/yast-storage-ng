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
require "installation/finish_client"

module Y2Storage
  module Clients
    # Finish client for storage-related tasks
    class Finish < ::Installation::FinishClient
      # Constructor
      def initialize
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
        true
      end

      # Enables multipathd in the targed system, if it is required.
      def enable_multipath
        return unless multipath?

        log.info "Enabling multipathd in the target system"
        Yast::Service.Enable("multipathd")
      end

      # Updates sysconfig file (/etc/sysconfig/storage) with current values
      # at StorageManager.
      #
      # @note This updates the sysconfig file in the target system.
      def update_sysconfig
        StorageManager.instance.update_sysconfig
      end

      # Checks whether multipath will be used in the target system
      # @return [Boolean]
      def multipath?
        staging = StorageManager.instance.staging
        features = UsedStorageFeatures.new(staging).collect_features
        features.include?(:UF_MULTIPATH)
      end
    end
  end
end
