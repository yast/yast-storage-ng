# Copyright (c) [2018-2020] SUSE LLC
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
require "yast/i18n"
require "yast2/popup"
require "y2partitioner/actions/base"
require "y2partitioner/execute_and_redraw"
require "y2partitioner/reprobe"
require "y2partitioner/icons"

Yast.import "Stage"
Yast.import "Popup"
Yast.import "Arch"
Yast.import "PackageCallbacks"
Yast.import "PackageSystem"

module Y2Partitioner
  module Actions
    # Actions collection for all actions in the "Configure" menu,
    # both in the main menu and on the "Configure" menu button.
    class ConfigureActions
      include Yast::I18n
      include Yast::Logger
      include Reprobe
      include ExecuteAndRedraw

      # Constructor
      def initialize
        textdomain "storage"
      end

      # Return the menu items for all the actions in this menu.
      # This filters out unsuitable actions (wrong architecture or
      # not supported during this stage of the installation).
      #
      # @return [Array<Yast::WidgetTerm>]
      def menu_items
        actions.map do |action|
          Yast::Term.new(
            :item,
            Yast::Term.new(:id, action.id),
            Yast::Term.new(:icon, action.icon),
            action.label)
        end
      end

      # Check if this actions collection contains an action for ID 'id'.
      def contain?(id)
        action = find_action(id)
        !action.nil?
      end

      def empty?
        actions.empty?
      end

      # Return an array of all action IDs
      def ids
        actions.map(&:id)
      end

      # Run the action for ID 'id'.
      #
      # @raise [Y2Partitioner::Error] if there is no action for this ID.
      def run(id)
        log.info("Running action for ID #{id}")
        action = find_action(id)
        raise Error, "No configure action defined for ID #{id}" if action.nil?
        return nil unless warning_accepted?(action) && availability_ensured?(action)

        execute_and_redraw do
          Yast::WFM.call(action.client) if action.client
          reprobe(activate: action.activate)
          :finish
        end
      end

      private

      # Available actions to be offered to the user
      #
      # @return [Array<ConfigureAction>]
      def actions
        @actions ||=
          if Yast::Stage.initial
            # In the inst-sys, check which clients are available
            supported_actions.reject(&:client_missing?)
          else
            # In the installed system, we don't care if the client is there or not
            # as the user will be prompted to install the pkg anyway (in #handle).
            supported_actions
          end
      end

      # Displays the action warning to the user
      #
      # @param action [ConfigureAction]
      # @return [Boolean] whether the user confirmed the warning message
      def warning_accepted?(action)
        Yast::Popup.YesNo(action.warning_text)
      end

      # Ensures the given action can be executed
      #
      # @param action [ConfigureAction]
      # @return [Boolean] false if it's not possible to run the action
      def availability_ensured?(action)
        # During installation only the really available actions are listed
        # (see #actions), so no need for extra checks
        return true if Yast::Stage.initial

        check_and_install_pkgs?(action)
      end

      # Checks whether the packages required to execute an action are present
      # and tries to install them if that's not the case
      #
      # @param action [ConfigureAction]
      # @return [Boolean] if the packages
      def check_and_install_pkgs?(action)
        pkgs = action.pkgs
        return true if pkgs.empty?

        # The following code (including the nice comment) is copied from the
        # old yast2-storage Partitioner

        # switch off pkg-mgmt loading progress dialogs,
        # because it just plain sucks
        Yast::PackageCallbacks.RegisterEmptyProgressCallbacks
        ret = Yast::PackageSystem.CheckAndInstallPackages(pkgs)
        Yast::PackageCallbacks.RestorePreviousProgressCallbacks
        ret
      end

      # Sorted list of actions
      def supported_actions
        @supported_actions ||= [
          ProvideCryptPasswords.new(_("Provide Crypt &Passwords..."), Icons::LOCK),
          ConfigureIscsi.new(_("Configure &iSCSI..."),         Icons::ISCSI),
          ConfigureFcoe.new(_("Configure &FCoE..."),           Icons::FCOE),
          ConfigureDasd.new(_("Configure &DASD..."),           Icons::DASD),
          ConfigureZfcp.new(_("Configure &zFCP..."),           Icons::ZFCP),
          ConfigureXpram.new(_("Configure &XPRAM..."),         Icons::XPRAM)
        ].select(&:supported?)
      end

      # ConfigureAction with the given id
      #
      # @param id [Symbol]
      # @return [ConfigureAction]
      def find_action(id)
        supported_actions.find { |action| action.id == id }
      end


      # Each one of the configuration actions offered by the widget and that
      # (usually) corresponds to a YaST client
      class ConfigureAction
        include Yast::I18n

        # Constructor
        #
        # @param label [String] see {#label}
        # @param icon [String] see {#icon}
        def initialize(label, icon)
          textdomain "storage"

          @label = label
          @icon = icon
        end

        # @return [Symbol] identifier for the action to use in the UI
        def id
          @id ||= snake_case(self.class.name.split("::").last).to_sym
        end

        # Convert a CamelCase ID like "FooBar" to snake_case like "foo_bar".
        def snake_case(id)
          id.gsub(/(.)([A-Z])/, "\\1_\\2").downcase
        end

        # @return [String] Internationalized label
        attr_reader :label

        # @return [String] name of the icon to display next to the label
        attr_reader :icon

        # Internationalized text to be displayed as a warning before executing the action
        #
        # Although all texts are almost identical, the whole literal strings are used
        # on each subclass in order to reuse the existing translations from yast2-storage
        #
        # @return [String]
        def warning_text
          ""
        end

        # Name of the YaST client implementing the action
        #
        # @return [Symbol, nil] nil if no separate client needs to be called
        def client
          nil
        end

        # Names of the packages needed to run the action
        #
        # @return [Array<String>]
        def pkgs
          []
        end

        # Whether the action is supported in the current system
        #
        # @return [Boolean]
        def supported?
          true
        end

        # Value for the 'activate' argument of {Reprobe#reprobe}
        #
        # For most cases this returns nil, which implies simply honoring the
        # default behavior.
        #
        # @return [Boolean, nil]
        def activate
          nil
        end

        # Check if the client that is needed to run the action is missing
        #
        # @return [Boolean]
        def client_missing?
          return false unless client

          !Yast::WFM.ClientExists(client)
        end
      end

      # Specific class for the activation action
      class ProvideCryptPasswords < ConfigureAction
        # @see ConfigureAction#warning_text
        def warning_text
          _(
            "Rescanning crypt devices cancels all current changes.\n" \
            "Really activate crypt devices?"
          )
        end

        # @see ConfigureAction#pkgs
        def pkgs
          ["cryptsetup"]
        end

        # @see ConfigureAction#activate
        def activate
          true
        end
      end

      # Specific action for running the iSCSI configuration client
      class ConfigureIscsi < ConfigureAction
        # @see ConfigureAction#warning_text
        def warning_text
          _(
            "Calling iSCSI configuration cancels all current changes.\n" \
            "Really call iSCSI configuration?"
          )
        end

        # @see ConfigureAction#client
        def client
          "iscsi-client"
        end

        # @see ConfigureAction#pkgs
        def pkgs
          ["yast2-iscsi-client"]
        end
      end

      # Specific action for running the FCoE configuration client
      class ConfigureFcoe < ConfigureAction
        # @see ConfigureAction#warning_text
        def warning_text
          _(
            "Calling FCoE configuration cancels all current changes.\n" \
            "Really call FCoE configuration?"
          )
        end

        # @see ConfigureAction#client
        def client
          "fcoe-client"
        end

        # @see ConfigureAction#pkgs
        def pkgs
          ["yast2-fcoe-client"]
        end
      end

      # Common base class for all the actions that are specific for S390
      class S390Action < ConfigureAction
        # @see ConfigureAction#pkgs
        def pkgs
          ["yast2-s390"]
        end

        # @see ConfigureAction#supported?
        def supported?
          Yast::Arch.s390
        end
      end

      # Specific action for running the DASD activation client
      class ConfigureDasd < S390Action
        # @see ConfigureAction#warning_text
        def warning_text
          _(
            "Calling DASD configuration cancels all current changes.\n" \
            "Really call DASD configuration?"
          )
        end

        # @see ConfigureAction#client
        def client
          "dasd"
        end
      end

      # Specific action for running the zFCP configuration client
      class ConfigureZfcp < S390Action
        # @see ConfigureAction#warning_text
        def warning_text
          _(
            "Calling zFCP configuration cancels all current changes.\n" \
            "Really call zFCP configuration?"
          )
        end

        # @see ConfigureAction#client
        def client
          "zfcp"
        end
      end

      # Specific action for running the XPRAM configuration client
      class ConfigureXpram < S390Action
        # @see ConfigureAction#warning_text
        def warning_text
          _(
            "Calling XPRAM configuration cancels all current changes.\n" \
            "Really call XPRAM configuration?"
          )
        end

        # @see ConfigureAction#client
        def client
          "xpram"
        end
      end
    end
  end
end
