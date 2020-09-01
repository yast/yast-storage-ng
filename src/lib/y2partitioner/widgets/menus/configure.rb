# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/execute_and_redraw"
require "y2partitioner/actions/configure_actions"

module Y2Partitioner
  module Widgets
    module Menus
      # Class to represent each one of the entries in the 'Configure' menu
      class ConfigureEntry
        include Yast::I18n
        extend Yast::I18n

        # Constructor
        def initialize(action_class_name, label, icon)
          @action_class_name = action_class_name
          @label = label
          @icon = icon
        end

        # All possible entries
        ALL = [
          new(:ProvideCryptPasswords, N_("Provide Crypt &Passwords..."), Icons::LOCK),
          new(:ConfigureIscsi,        N_("Configure &iSCSI..."),         Icons::ISCSI),
          new(:ConfigureFcoe,         N_("Configure &FCoE..."),          Icons::FCOE),
          new(:ConfigureDasd,         N_("Configure &DASD..."),          Icons::DASD),
          new(:ConfigureZfcp,         N_("Configure &zFCP..."),          Icons::ZFCP),
          new(:ConfigureXpram,        N_("Configure &XPRAM..."),         Icons::XPRAM)
        ]
        private_constant :ALL

        # All possible entries
        #
        # @return [Array<ConfigureEntry>]
        def self.all
          ALL.dup
        end

        # Entries that should be displayed to the user
        #
        # @return [Array<ConfigureEntry>]
        def self.visible
          all.select(&:visible?)
        end

        # @return [String] name of the icon to display next to the label
        attr_reader :icon

        # @return [String] Internationalized label
        def label
          _(@label)
        end

        # @return [Symbol] identifier for the action to use in the UI
        def id
          @id ||= action_class_name.to_s.gsub(/(.)([A-Z])/, '\1_\2').downcase.to_sym
        end

        # Action to execute when the entry is selected
        #
        # @return [Y2Partitioner::Actions::ConfigureAction]
        def action
          @action ||= Y2Partitioner::Actions.const_get(action_class_name).new
        end

        # Whether the entry should be displayed to the user
        #
        # @return [Boolean]
        def visible?
          action.available?
        end

        private

        # Name of the class for #{action}
        #
        # @return [Symbol]
        attr_reader :action_class_name
      end

      class Configure
        include Yast::I18n
        include ExecuteAndRedraw

        def initialize
          @configure_entries = ConfigureEntry.visible
        end

        def label
          _("&Configure")         
        end

        def items
          @configure_entries.map do |entry|
            Yast::Term.new(
              :item,
              Yast::Term.new(:id, entry.id),
              Yast::Term.new(:icon, entry.icon),
              entry.label
            )
          end
        end

        def handle(event)
          action = action_for(event)
          return nil unless action

          execute_and_redraw { action.run }
        end

        private

        def action_for(event)
          entry = @configure_entries.find { |e| e.id == event }
          entry&.action
        end
      end
    end
  end
end
