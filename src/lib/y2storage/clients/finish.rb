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

      # Modes in which the client should run
      # @return [Array<Symbol>]
      def modes
        [:installation, :update, :autoinst, :autoupg, :live_installation]
      end

      # Performs the final actions in the target system
      def write
        return unless multipath?

        log.info "Enabling multipathd in the target system"
        Yast::Service.Enable("multipathd")
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
