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
require "y2partitioner/icons"
require "y2partitioner/widgets/summary_text"

Yast.import "Mode"

module Y2Partitioner
  module Widgets
    module Pages
      # A page for displaying the Installation Summary
      class Summary < CWM::Page
        include Yast::I18n

        # Constructor
        def initialize
          textdomain "storage"
        end

        # @macro seeAbstractWidget
        def label
          _("Installation Summary")
        end

        # @macro seeAbstractWidget
        def help
          Yast::Mode.installation ? help_installation : help_installed_system
        end

        def help_installation
          _("<p><b>Installation Summary:</b> " \
            "This shows the actions that will be performed " \
            "when you confirm the installation. " \
            "Until then, nothing is changed on your system." \
            "</p>")
        end

        def help_installed_system
          _("<p><b>Installation Summary:</b> " \
            "This shows the actions that will be performed " \
            "when you finish the partitioner. " \
            "So far, nothing has been changed yet on your system." \
            "</p>")
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          icon = Icons.small_icon(Icons::SUMMARY)
          @contents = VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading for the expert partitioner page
                Heading(_("Installation Summary"))
              )
            ),
            SummaryText.new
          )
        end
      end
    end
  end
end
