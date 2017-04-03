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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage"
require "ui/installation_dialog"

Yast.import "Report"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Base class for guided setup dialogs.
      class Base < ::UI::InstallationDialog
        # Current settings with user selections.
        attr_accessor :settings

        def initialize(guided_setup, settings)
          super()
          log.info "#{self.class}: start with #{settings.inspect}"
          textdomain "storage-ng"
          @guided_setup = guided_setup
          @settings = settings
        end

        # Only continues if settings are correctly updated. In other case,
        # an error dialogs is expected.
        def next_handler
          if update_settings!
            log.info "#{self.class}: return :next with #{settings.inspect}"
            super
          end
        end

        def back_handler
          log.info "#{self.class}: return :back with #{settings.inspect}"
          super
        end

      protected

        # Controller object needed to access to pre-calculated data.
        attr_reader :guided_setup

        def create_dialog
          super
          initialize_widgets
          true
        end

        # Should be implemented by derived classes.
        def initialize_widgets
          true
        end

        # Should be implemented by derived classes.
        def update_settings!
          true
        end

        def help_text
          _(
            "<p>\n" \
            "TODO: this dialog is just temporary. " \
            "Hopefully it will end up including help of each setup.</p>"
          )
        end

        def disks_data
          guided_setup.disks_data
        end

        # Helper to get widget value
        def widget_value(id, attr: :Value)
          Yast::UI.QueryWidget(Id(id), attr)
        end

        # Helper to set widget value
        def widget_update(id, value, attr: :Value)
          Yast::UI.ChangeWidget(Id(id), attr, value)
        end
      end
    end
  end
end
