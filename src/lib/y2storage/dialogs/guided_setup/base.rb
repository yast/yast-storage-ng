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

module Y2Storage
  module Dialogs
    class GuidedSetup
      class Base < ::UI::InstallationDialog

        def initialize(guided_setup)
          super()
          textdomain "storage-ng"
          @guided_setup = guided_setup
          log.info "#{label}: start with #{settings.inspect}"
        end

        def next_handler
          push_settings
          log.info "#{label}: return :next with #{settings.inspect}"
          super
        end

        def back_handler
          pop_settings
          log.info "#{label}: return :back with #{settings.inspect}"
          super
        end

      protected

        def settings
          @guided_setup.settings_stack.last
        end

        def push_settings
          @guided_setup.settings_stack << settings.dup
        end

        def pop_settings
          @guided_setup.settings_stack.pop
        end

        def help_text
          _(
            "<p>\n" \
            "TODO: this dialog is just temporary. " \
            "Hopefully it will end up including several steps.</p>"
          )
        end

        def widget_value(id, attr: :Value)
          Yast::UI.QueryWidget(Id(id), attr)
        end

        def widget_update(id, value, attr: :Value)
          Yast::UI.ChangeWidget(Id(id), attr, value)
        end
      end
    end
  end
end
