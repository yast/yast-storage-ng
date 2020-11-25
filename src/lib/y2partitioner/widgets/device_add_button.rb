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

require "abstract_method"
require "y2partitioner/widgets/device_button"

module Y2Partitioner
  module Widgets
    # Base class for buttons which add a device to a given device, for example, to add partition to a
    # disk or to add a logical volume to a LVM volume group.
    class DeviceAddButton < DeviceButton
      # @see DeviceButton#device
      def device
        dev = super
        return unless dev

        device_or_parent(dev)
      end

      # @!method device_or_parent(device)
      #   Finds the correct device for the action
      #
      #   @param device [Y2Storage::Device]
      #   @return [Y2Storage::Device]
      abstract_method :device_or_parent
    end
  end
end
