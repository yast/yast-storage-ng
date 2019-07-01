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
require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/encrypt_password"

module Y2Partitioner
  module Dialogs
    # Ask for a password to assign to an encrypted device.
    # Part of {Actions::AddPartition} and {Actions::EditBlkDevice}.
    # Formerly MiniWorkflowStepPassword
    class EncryptPassword < Base
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      def title
        _("Encryption password for %s") % @controller.blk_device_name
      end

      def contents
        HVSquash(
          Widgets::EncryptPassword.new(@controller)
        )
      end
    end
  end
end
