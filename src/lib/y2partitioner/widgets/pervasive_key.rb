# Copyright (c) [2020-2024] SUSE LLC
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

module Y2Partitioner
  module Widgets
    # Widget to display the full verification pattern for the selected master key, in case the
    # pattern is too long to be displayed at the corresponding selector
    class PervasiveKey < CWM::ReplacePoint
      # Internal widget showing the full verification pattern split into several lines
      class Label < CWM::CustomWidget
        # Constructor
        def initialize(widget_id, key)
          super()
          self.widget_id = widget_id
          @key = key
        end

        # @macro seeCustomWidget
        def contents
          lines = [@key[0..33], "  #{@key[34..-1]}"]
          Left(Label(lines.join("\n")))
        end
      end

      # Constructor
      #
      # @param initial_key [String]
      def initialize(initial_key)
        textdomain "storage"

        super(id: "pervasive_key", widget: widget_for(initial_key))
      end

      # Redraws the widget to show the new key, if needed
      #
      # @param key [String]
      def refresh(key)
        replace(widget_for(key))
      end

      private

      # Empty widget or multi-line label
      def widget_for(key)
        widget_id = "FullKey#{key}"
        if key.size > 20
          Label.new(widget_id, key)
        else
          CWM::Empty.new(widget_id)
        end
      end
    end
  end
end
