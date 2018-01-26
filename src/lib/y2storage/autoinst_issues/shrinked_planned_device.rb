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

require "y2storage/autoinst_issues/issue"

module Y2Storage
  module AutoinstIssues
    # Represents an AutoYaST situation where no suitable disk was found.
    #
    # This is a fatal error because AutoYaST needs to determine which disks will be used
    # during installation.
    class ShrinkedPlannedDevice < Issue
      attr_reader :planned_device
      attr_reader :real_device

      # @param section [#parent,#section_name] Section where it was detected (see {AutoinstProfile})
      def initialize(planned_device, real_device)
        @planned_device = planned_device
        @real_device = real_device
      end

      # Return problem severity
      #
      # @return [Symbol] :fatal
      def severity
        :warn
      end

      def diff
        planned_device.min_size - real_device.size
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        # TRANSLATORS:
        _("Size for %s will be reduced from %s to %s") % [device_identifier,
          planned_device.min_size.to_human_string,
          real_device.size.to_human_string]
      end

    private

      def device_identifier
        if planned_device.mount_point
          "#{planned_device.mount_point} (#{real_device.name})"
        elsif planned_device.filesystem
          "#{planned_device.filesystem} (#{real_device.name})"
        else
          real_device.name
        end
      end
    end
  end
end

