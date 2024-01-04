# Copyright (c) [2020] SUSE LLC
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

require "cwm"

module Y2Partitioner
  module Widgets
    # Widget to enable or disable quota support in the Btrfs filesystem
    class BtrfsQuota < CWM::CheckBox
      # Constructor
      #
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        super()
        textdomain "storage"
        @controller = controller
      end

      # @macro seeAbstractWidget
      def label
        _("Enable Subvolume Quotas")
      end

      # @macro seeAbstractWidget
      def help
        format(
          # TRANSLATORS: help text for the widget to enable subvolume quotas,
          # where %{label} is the label of the widget
          _("<p><b>%{label}</b> can be used to turn on and off the quota support " \
            "for this Btrfs file system. When quotas are enabled, the exact space " \
            "used and referenced by each subvolume is constantly accounted and can " \
            "be limited. In that case, the max referenced space for each subvolume " \
            "can be set while creating or editing that subvolume.</p>" \
            "<p>Enabling quotas also makes possible to know exactly how much space " \
            "would be freed by deleting a given snapshot or subvolume (the so-called " \
            "exclusive space).</p>" \
            "<p>When quotas are activated, they affect all operations in the file " \
            "system, which takes a performance hit. Activation of quotas is not " \
            "recommended unless the user intends to actually use them. Moreover, " \
            "Btrfs quotas have been reported to produce system instability and to " \
            "present incorrect space accounting in some cases. The situation is " \
            "gradually improving as the issues are being found and fixed.</p>"), label:
        )
      end

      # @macro seeAbstractWidget
      def opt
        [:notify]
      end

      # Synchronizes the widget with the information from the controller
      def init
        self.value = @controller.btrfs_quota?
      end

      # @macro seeAbstractWidget
      def handle(event)
        @controller.btrfs_quota = value if event["ID"] == widget_id
        nil
      end
    end
  end
end
