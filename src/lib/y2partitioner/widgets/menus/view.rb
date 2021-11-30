# Copyright (c) [2020-2021] SUSE LLC
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
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/menus/base"
require "y2partitioner/dialogs/summary_popup"
require "y2partitioner/dialogs/device_graph"
require "y2partitioner/dialogs/settings"
require "y2partitioner/dialogs/bcache_csets"
require "y2partitioner/dialogs/probing_issues"

module Y2Partitioner
  module Widgets
    module Menus
      # Class to represent the View menu
      class View < Base
        # @see Base
        def initialize(*args)
          textdomain "storage"
          super
        end

        # @see Base
        def label
          # TRANSLATORS: Partitioner menu with some special dialogs
          _("&View")
        end

        # @see Base
        def items
          return @items if @items

          @items =
            if Dialogs::DeviceGraph.supported?
              [Item(Id(:device_graphs), _("Device &Graphs..."))]
            else
              []
            end

          @items += [
            Item(Id(:installation_summary), _("Installation &Summary...")),
            Item(Id(:settings), _("Se&ttings...")),
            Item(Id(:bcache_csets), _("&Bcache Caching Sets...")),
            Item(Id(:system_issues), _("&System Issues..."))
          ]
        end

        # @see Base
        def disabled_items
          default = super
          return default if probing_issues?

          # if there are no issues, then :system_issues is disabled
          default + [:system_issues]
        end

        private

        # @see Base
        def dialog_for(event)
          case event
          when :device_graphs
            Dialogs::DeviceGraph.new
          when :installation_summary
            Dialogs::SummaryPopup.new
          when :settings
            Dialogs::Settings.new
          when :bcache_csets
            Dialogs::BcacheCsets.new
          when :system_issues
            Dialogs::ProbingIssues.new
          end
        end

        def probing_issues?
          DeviceGraphs.instance.system.issues_manager.probing_issues.any?
        end
      end
    end
  end
end
