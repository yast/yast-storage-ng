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
require "cwm"
require "y2partitioner/widgets/reprobe"
require "y2partitioner/widgets/execute_and_redraw"
require "y2partitioner/icons"

Yast.import "Stage"
Yast.import "Popup"
Yast.import "Arch"
Yast.import "PackageCallbacks"
Yast.import "PackageSystem"

module Y2Partitioner
  module Widgets
    # "Configure" menu button used to run the corresponding YaST clients to
    # activate several storage technologies
    #
    # Most of the behavior of this widget is a direct translation of the old
    # Yast::PartitioningEpAllInclude from yast-storage
    class Configure < CWM::CustomWidget
      include Reprobe
      include ExecuteAndRedraw

      # Constructor
      def initialize
        textdomain "storage"
        super
      end

      # Content of the widget, a menu button with the list of available
      # configuration clients or an empty widget if no client is available
      #
      # @macro seeCustomWidget
      #
      # @return [Yast::WidgetTerm]
      def contents
        @contents ||= actions.empty? ? Empty() : MenuButton(Opt(*opt), label, items)
      end

      # Event handler for the configuration menu
      #
      # @param event [Hash] UI event
      # @return [:redraw, nil] :redraw when some configuration client was
      #   executed; nil otherwise.
      def handle(event)
        action = find_action(event["ID"])

        return nil unless action
        return nil unless warning_accepted?(action) && availability_ensured?(action)

        execute_and_redraw do
          Yast::WFM.call(action.client) if action.client
          reprobe(activate: action.activate)
          :finish
        end
      end

      # @macro seeAbstractWidget
      def help
        # TRANSLATORS: help text for the Partitioner
        _(
          "<p>The <b>Configure</b> button offers several options to activate devices " \
          "that were not detected by the initial system analysis. After activating the " \
          "devices of the choosen technology, the system will be rescanned and all the " \
          "information about storage devices will be refreshed. " \
          "Thus, the <b>Provide Crypt Passwords</b> option is also useful when no " \
          "encryption is involved, to activate devices of other technologies like LVM " \
          "or Multipath.</p>"
        )
      end

      private

      # @return [Array<Yast::WidgetTerm>]
      def items
        actions.map do |action|
          Item(Id(action.id), Yast::Term.new(:icon, action.icon), action.label)
        end
      end

      # @return [Array<Symbol>]
      def opt
        [:key_F7]
      end

      # Localized label for the menu button
      #
      # @return [String]
      def label
        # Translators: Configure menu in the initial Partitioner screen
        _("Configure...")
      end

      # @macro seeCustomWidget
      #
      # Redefined in this class because the base implementation at CWM::CustomWidget
      # does not search for ids into the items of a MenuButton.
      def ids_in_contents
        actions.map(&:id)
      end

      # Available actions to be offered to the user
      #
      # @return [Array<Action>]
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
      # @param action [Action]
      # @return [Boolean] whether the user confirmed the warning message
      def warning_accepted?(action)
        Yast::Popup.YesNo(action.warning_text)
      end

      # Ensures the given action can be executed
      #
      # @param action [Action]
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
      # @param action [Action]
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
          CryptAction.new(_("Provide Crypt &Passwords..."), Icons::LOCK),
          IscsiAction.new(_("Configure &iSCSI..."),         Icons::ISCSI),
          FcoeAction.new(_("Configure &FCoE..."),           Icons::FCOE),
          DasdAction.new(_("Configure &DASD..."),           Icons::DASD),
          ZfcpAction.new(_("Configure &zFCP..."),           Icons::ZFCP),
          XpramAction.new(_("Configure &XPRAM..."),         Icons::XPRAM)
        ].select(&:supported?)
      end

      # Action with the given id
      #
      # @param id [Symbol]
      # @return [Action]
      def find_action(id)
        supported_actions.find { |action| action.id == id }
      end

      # Each one of the configuration actions offered by the widget and that
      # (usually) corresponds to a YaST client
      class Action
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
          @id ||= self.class.name.split("::").last.to_sym
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

        # Whether the client needed to run the action is missing
        #
        # @return [Boolean]
        def client_missing?
          return false unless client

          !Yast::WFM.ClientExists(client)
        end
      end

      # Specific class for the activation action
      class CryptAction < Action
        # @see Action#warning_text
        def warning_text
          _(
            "Rescanning crypt devices cancels all current changes.\n" \
            "Really activate crypt devices?"
          )
        end

        # @see Action#pkgs
        def pkgs
          ["cryptsetup"]
        end

        # @see Action#activate
        def activate
          true
        end
      end

      # Specific action for running the iSCSI configuration client
      class IscsiAction < Action
        # @see Action#warning_text
        def warning_text
          _(
            "Calling iSCSI configuration cancels all current changes.\n" \
            "Really call iSCSI configuration?"
          )
        end

        # @see Action#client
        def client
          "iscsi-client"
        end

        # @see Action#pkgs
        def pkgs
          ["yast2-iscsi-client"]
        end
      end

      # Specific action for running the FCoE configuration client
      class FcoeAction < Action
        # @see Action#warning_text
        def warning_text
          _(
            "Calling FCoE configuration cancels all current changes.\n" \
            "Really call FCoE configuration?"
          )
        end

        # @see Action#client
        def client
          "fcoe-client"
        end

        # @see Action#pkgs
        def pkgs
          ["yast2-fcoe-client"]
        end
      end

      # Common base class for all the actions that are specific for S390
      class S390Action < Action
        # @see Action#pkgs
        def pkgs
          ["yast2-s390"]
        end

        # @see Action#supported?
        def supported?
          Yast::Arch.s390
        end
      end

      # Specific action for running the DASD activation client
      class DasdAction < S390Action
        # @see Action#warning_text
        def warning_text
          _(
            "Calling DASD configuration cancels all current changes.\n" \
            "Really call DASD configuration?"
          )
        end

        # @see Action#client
        def client
          "dasd"
        end
      end

      # Specific action for running the zFCP configuration client
      class ZfcpAction < S390Action
        # @see Action#warning_text
        def warning_text
          _(
            "Calling zFCP configuration cancels all current changes.\n" \
            "Really call zFCP configuration?"
          )
        end

        # @see Action#client
        def client
          "zfcp"
        end
      end

      # Specific action for running the XPRAM configuration client
      class XpramAction < S390Action
        # @see Action#warning_text
        def warning_text
          _(
            "Calling XPRAM configuration cancels all current changes.\n" \
            "Really call XPRAM configuration?"
          )
        end

        # @see Action#client
        def client
          "xpram"
        end
      end
    end
  end
end
