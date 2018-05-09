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
require "cwm"
require "y2partitioner/widgets/reprobe"

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
        @contents ||= actions.empty? ? Empty() : MenuButton(opt, label, items)
      end

      # Event handler for the configuration menu
      #
      # @param event [Hash] UI event
      # @return [:reprobe, nil] :reprobe when some configuration client was
      #   executed; nil otherwise.
      def handle(event)
        action = Action.find(event["ID"])

        return nil unless action
        return nil unless warning_accepted?(action) && availability_ensured?(action)

        Yast::WFM.call(action.client)
        reprobe
        :reprobe
      end

    private

      # @return [Array<Yast::WidgetTerm>]
      def items
        actions.map do |action|
          Item(Id(action.id), Yast::Term.new(:icon, action.icon), action.label)
        end
      end

      # @return [Yast::WidgetTerm]
      def opt
        Opt(:key_F7)
      end

      # Localized label for the menu button
      #
      # @return [String]
      def label
        # Translators: Configure menu in the initial Partitioner screen
        _("Configure...")
      end

      # @macro seeCustomWidget
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
            Action.supported.select { |action| Yast::WFM.ClientExists(action.client) }
          else
            # In the installed system, we don't care if the client is there or not
            # as the user will be prompted to install the pkg anyway (in #handle).
            Action.supported
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

      # Each one of the configuration actions offered by the widget and that
      # corresponds to a YaST client
      class Action
        include Yast::I18n
        extend Yast::I18n

        textdomain "storage"

        # Constructor
        #
        # @param id [Symbol] see {#id}
        # @param label [String] string marked for translation to be used by {#label}
        # @param icon [String] see {#icon}
        # @param pkgs [Array<String>] see {#pkgs}
        def initialize(id, label, icon, client, pkgs)
          textdomain "storage"

          @id = id
          @label = label
          @icon = icon
          @client = client
          @pkgs = pkgs
        end

        # Sorted list of actions
        ALL = [
          new(:iscsi, N_("Configure &iSCSI..."), "yast-iscsi-client", "iscsi-client",
            ["yast2-iscsi-client"]),
          new(:fcoe,  N_("Configure &FCoE..."),  "fcoe",              "fcoe-client",
            ["yast2-fcoe-client"]),
          new(:dasd,  N_("Configure &DASD..."),  "yast-dasd",         "dasd",
            ["yast2-s390"]),
          new(:zfcp,  N_("Configure &zFCP..."),  "yast-zfcp",         "zfcp",
            ["yast2-s390"]),
          new(:xpram, N_("Configure &XPRAM..."), "yast-xpram",        "xpram",
            ["yast2-s390"])
        ].freeze
        private_constant :ALL

        # Texts for {#warning_text}
        #
        # Although all texts are almost identical, the whole literal strings
        # are indexed in this constant in order to reuse the existing
        # translations from yast2-storage
        WARNING_TEXTS = {
          iscsi: N_(
            "Calling iSCSI configuration cancels all current changes.\n" \
            "Really call iSCSI configuration?"
          ),
          fcoe:  N_(
            "Calling FCoE configuration cancels all current changes.\n" \
            "Really call FCoE configuration?"
          ),
          dasd:  N_(
            "Calling DASD configuration cancels all current changes.\n" \
            "Really call DASD configuration?"
          ),
          fzcp:  N_(
            "Calling zFCP configuration cancels all current changes.\n" \
            "Really call zFCP configuration?"
          ),
          xpram: N_(
            "Calling XPRAM configuration cancels all current changes.\n" \
            "Really call XPRAM configuration?"
          )
        }

        # Actions that can only be executed on s390 systems
        S390_IDS = [:dasd, :zfcp, :xpram].freeze
        private_constant :S390_IDS

        # Action with the given id
        #
        # @param id [Symbol]
        # @return [Action]
        def self.find(id)
          ALL.find { |action| action.id == id }
        end

        # Actions that are supported in the current system
        #
        # @return [Array<Action>]
        def self.supported
          ALL.select(&:supported?)
        end

        # @return [Symbol] identifier for the action
        attr_reader :id

        # @return [Symbol] identifier for the action
        attr_reader :icon

        # @return [String] name of the icon to display next to the label
        attr_reader :client

        # @return [Array<String>] name of the packages needed to run the action
        attr_reader :pkgs

        # Internationalized label
        #
        # @return [String]
        def label
          _(@label)
        end

        # Internationalized text to be displayed as a warning before executing the action
        #
        # @return [String]
        def warning_text
          _(WARNING_TEXTS[id])
        end

        # Whether the action is supported in the current system
        #
        # @return [Boolean]
        def supported?
          S390_IDS.include?(id) ? Yast::Arch.s390 : true
        end
      end
    end
  end
end
