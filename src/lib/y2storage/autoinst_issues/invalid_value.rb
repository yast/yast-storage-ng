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
    # Represents an AutoYaST situation where an invalid value was given.
    #
    # @example Invalid value 'auto' for attribute :size on /home partition
    #   problem = MissingValue.new("/home", :size, "auto")
    class InvalidValue < Issue
      # @return [String] Device affected by this error
      attr_reader :device
      # @return [Symbol] Name of the missing attribute
      attr_reader :attr
      # @return [Object] Invalid value
      attr_reader :value
      # @return [Object] New value or :skip to skip the section.
      attr_reader :new_value

      # @param device    [String] Device (`/`, `/dev/sda`, etc.)
      # @param attr      [Symbol] Name of the missing attribute
      # @param value     [Integer,String,Symbol] Invalid value
      # @param new_value [Integer,String,Symbol] New value or :skip to skip the section
      def initialize(device, attr, value, new_value = :skip)
        @device = device
        @attr = attr
        @value = value
        @new_value = new_value
      end

      # Return problem severity
      #
      # @return [Symbol] :warn
      def severity
        :warn
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        format(
          # TRANSLATORS: 1: generic value; 2: AutoYaST attribute name; 3: device name (eg. /dev/sda1);
          # 4: short explanation about what should be done with the value
          _("Invalid value '%s' for attribute '%s' on '%s' (%s)."),
          value, attr, device, new_value_message
        )
      end

    private

      # Return a messsage explaining what should be done with the value.
      def new_value_message
        if new_value == :skip
          _("the section will be skipped")
        else
          _(format("replaced by '%<value>s'", value: new_value))
        end
      end
    end
  end
end
