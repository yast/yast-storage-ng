# Copyright (c) [2021] SUSE LLC
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

module Y2Partitioner
  # Utility class for unmounting a device
  class Unmounter
    include Yast::Logger

    # Error when unmounting the device
    #
    # @return [String, nil]
    attr_reader :error

    # Constructor
    #
    # @param device [Y2Storage::Mountable] device to unmount
    def initialize(device)
      @device = device
    end

    # Unmounts the device
    #
    # @return [Boolean] whether the device was successfully unmounted
    def unmount
      device.mount_point.immediate_deactivate
      true
    rescue Storage::Exception => e
      log.warn "failed to unmount #{device}: #{e.what}"
      @error = e.what
      false
    end

    # Whether there was an error when unmounting the device
    def error?
      !error.nil?
    end

    private

    # @return [Y2Storage::Mountable]
    attr_reader :device
  end
end
