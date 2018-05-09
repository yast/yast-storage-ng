# encoding: utf-8

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
require "cwm/common_widgets"
require "cwm/custom_widget"
require "y2storage"
require "y2partitioner/dialogs/base"
require "y2partitioner/filesystem_role"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Determine the role of the new partition or LVM logical volume to be
    # created which will allow to propose some default format and mount options
    # for it.
    # Part of {Actions::AddPartition}.
    # Formerly MiniWorkflowStepRole
    class PartitionRole < Base
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(RoleChoice.new(controller))
      end

    private

      attr_reader :controller

      # Choose the role of the new partition
      class RoleChoice < CWM::RadioButtons
        # @param controller [Actions::Controllers::Filesystem]
        def initialize(controller)
          textdomain "storage"

          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Role")
        end

        # @macro seeAbstractWidget
        def help
          _("<p>Choose the role of the device.</p>")
        end

        def items
          FilesystemRole.all.map { |role| [role.id, role.name] }
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.role_id || :data
        end

        # @macro seeAbstractWidget
        def store
          @controller.role_id = value
        end
      end
    end
  end
end
