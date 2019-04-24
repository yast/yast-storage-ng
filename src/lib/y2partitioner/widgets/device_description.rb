# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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

require "cwm/widget"
require "y2partitioner/widgets/help"
require "abstract_method"

Yast.import "HTML"

module Y2Partitioner
  module Widgets
    # Base class for a device description
    #
    # A device description is composed by sections, see {DescriptionSection::Base}.
    class DeviceDescription < CWM::RichText
      include Yast::I18n
      include Help

      # Constructor
      #
      # @param device [Y2Storage::Device]
      def initialize(device)
        textdomain "storage"
        @device = device
      end

      # @macro seeAbstractWidget
      def init
        self.value = device_description
      end

      # @macro seeAbstractWidget
      #
      # Help texts are provided by {Help} module.
      def help
        help_texts = help_fields.map { |a| helptext_for(a) }.join("\n")
        help_header + help_texts
      end

    private

      # @return [Y2Storage::Device]
      attr_reader :device

      # Header to show in help
      #
      # @see #help
      #
      # @return [String]
      def help_header
        _(
          "<p>This view shows detailed information about the selected device.</p>\n" \
          "<p>The overview contains:</p>"
        )
      end

      # Fields for help
      #
      # @see #help
      #
      # @return [Array<Symbol>]
      def help_fields
        sections.map(&:help_fields).flatten
      end

      # Description for a device
      #
      # @return [String]
      def device_description
        sections.map(&:value).join
      end

      # @!method sections
      #   Sections to describe a device
      #
      #   @return [Array<DescriptionSection::Base>]
      abstract_method :sections
    end
  end
end
