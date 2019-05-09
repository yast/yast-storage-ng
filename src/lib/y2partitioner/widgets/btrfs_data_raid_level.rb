# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "cwm"
require "y2storage/btrfs_raid_level"

module Y2Partitioner
  module Widgets
    # Widget to select the data RAID level for a Btrfs filesystem
    class BtrfsDataRaidLevel < CWM::ComboBox
      # Constructor
      #
      # @param controller [Actions::Controllers::BtrfsDevices]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: widget label
        _("RAID Level")
      end

      # @macro seeAbstractWidget
      def help
        # TRANSLATORS: widget help, where %{label} is replaced by the label of the widget.
        format(
          _("<p><b>%{label}:</b> RAID level for the Btrfs data.</p>"),
          label: label
        )
      end

      # @macro seeAbstractWidget
      def opt
        [:notify]
      end

      # @macro seeAbstractWidget
      def items
        @controller.raid_levels.map { |p| [p.to_s, p.to_human_string] }
      end

      # @macro seeAbstractWidget
      def init
        self.value = @controller.data_raid_level.to_s
      end

      # @macro seeAbstractWidget
      def handle
        @controller.data_raid_level = Y2Storage::BtrfsRaidLevel.find(value)

        nil
      end
    end
  end
end
