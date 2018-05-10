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
require "yast/i18n"
require "yast2/popup"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Actions
    # Action when quiting the Expert Partitioner
    #
    # Before quiting the Expert Partitioner, some checks must be performed.
    # For example, it is necessary to check whether some devices or settings
    # have been modified, and in such case, notify the user about it.
    class QuitPartitioner
      include Yast::I18n

      # Constructor
      def initialize
        textdomain "storage"
      end

      # Checks whether there are changes, and it that case, asks to the user for
      # confirmation to exit
      #
      # @return [:quit, nil] :quit if there are no changes or the user decides
      #   to proceed.
      def run
        return :quit unless system_edited?

        confirmation == :yes ? :quit : nil
      end

      # Whether to quit the Expert Partitioner
      #
      # @see #run
      #
      # @return [Boolean]
      def quit?
        run == :quit
      end

    private

      # Whether the system has been edited (devices or settings)
      #
      # TODO: add check for modifications in Partitioner settings
      #
      # @return [Boolean]
      def system_edited?
        DeviceGraphs.instance.devices_edited?
      end

      # Confirmation popup before quiting the Expert Partitioner
      #
      # @return [:symbol] :yes, :no
      def confirmation
        message = _(
          "You have modified some devices. These changes will be lost\n" \
          "if you exit the Partitioner.\n" \
          "Really exit?"
        )

        Yast2::Popup.show(message, buttons: :yes_no)
      end
    end
  end
end
