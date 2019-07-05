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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"

module Y2Storage
  module Dialogs
    class GuidedSetup
      module Widgets
        # Base class for widgets in the dialogs of the Guided Setup
        class Base
          include Yast::UIShortcuts
          include Yast::I18n

          # @return [String]
          attr_reader :widget_id

          # Constructor
          #
          # @param widget_id [String]
          # @param settings [Y2Storage::ProposalSettings]
          def initialize(widget_id, settings)
            @widget_id = widget_id
            @settings = settings
          end

          # Content of the widget
          #
          # This method must be defined by derived classes.
          #
          # @return [Yast::Term, nil]
          def content
            nil
          end

          # Initializes the widget
          #
          # This method should be defined by derived classes.
          def init
            nil
          end

          # Stores the widget
          #
          # This method should be defined by derived classes.
          def store
            nil
          end

          # Help for the widget
          #
          # This method should be defined by derived classes.
          #
          # @return [String, nil]
          def help
            nil
          end

          # Value of the widget
          #
          # @return [Object]
          def value
            Yast::UI.QueryWidget(Id(widget_id), :Value)
          end

          # Setter for the value of the widget
          #
          # @param value [Object]
          def value=(value)
            Yast::UI.ChangeWidget(Id(widget_id), :Value, value)
          end

          # Enables the widget
          def enable
            Yast::UI.ChangeWidget(Id(widget_id), :Enabled, true)
          end

          # Disables the widget
          def disable
            Yast::UI.ChangeWidget(Id(widget_id), :Enabled, false)
          end

          # Whether the widget is currently enabled
          #
          # @return [Boolean]
          def enabled?
            Yast::UI.QueryWidget(Id(widget_id), :Enabled)
          end

          private

          # @return [Y2Storage::ProposalSettings]
          attr_reader :settings
        end
      end
    end
  end
end
