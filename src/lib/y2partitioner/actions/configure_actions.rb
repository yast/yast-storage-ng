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
require "y2partitioner/reprobe"

Yast.import "Stage"
Yast.import "Popup"
Yast.import "Arch"
Yast.import "PackageCallbacks"
Yast.import "PackageSystem"

module Y2Partitioner
  module Actions
    # Base class for the configuration actions
    #
    # Each subclass (usually) corresponds to a YaST client
    class ConfigureAction < Base
      include Reprobe

      # Constructor
      def initialize
        super
        textdomain "storage"
      end

      # Whether it makes sense to offer the action in the UI
      #
      # @return [Boolean]
      def available?
        if installation?
          # In the inst-sys, check whether the client is available
          supported? && !client_missing?
        else
          # In the installed system, we don't care if the client is there or not as the
          # user will be prompted to install the pkg anyway (in #perform_action)
          supported?
        end
      end

      private

      # @see Actions::Base#perform_action
      def perform_action
        return unless warning_accepted? && availability_ensured?

        Yast::WFM.call(client) if client
        reprobe(activate: activate)

        :finish
      end

      # Whether YaST is running in the initial stage of installation
      #
      # @return [Boolean]
      def installation?
        Yast::Stage.initial
      end

      # Whether the action is supported in the current system
      #
      # @return [Boolean]
      def supported?
        true
      end

      # Check if the client that is needed to run the action is missing
      #
      # @return [Boolean]
      def client_missing?
        return false unless client

        !Yast::WFM.ClientExists(client)
      end

      # Displays the action warning to the user
      #
      # @return [Boolean] whether the user confirmed the warning message
      def warning_accepted?
        Yast::Popup.YesNo(warning_text)
      end

      # Ensures the action can be executed
      #
      # @return [Boolean] false if it's not possible to run the action
      def availability_ensured?
        # During installation only the really available actions are offered in
        # the UI, so no need for extra checks
        return true if installation?

        check_and_install_pkgs?
      end

      # Checks whether the packages required to execute an action are present
      # and tries to install them if that's not the case
      #
      # @return [Boolean] if the packages
      def check_and_install_pkgs?
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

      # Value for the 'activate' argument of {Reprobe#reprobe}
      #
      # For most cases this returns nil, which implies simply honoring the
      # default behavior.
      #
      # @return [Boolean, nil]
      def activate
        nil
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
