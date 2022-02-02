# Copyright (c) [2022] SUSE LLC
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
require "y2partitioner/dialogs/single_step"

Yast.import "Stage"
Yast.import "PackageCallbacks"
Yast.import "Package"

module Y2Partitioner
  module Dialogs
    # Dialog to create and edit an NFS mount
    class Nfs < SingleStep
      include Yast::Logger

      # Name of the yast2-nfs-client package
      PACKAGE = "yast2-nfs-client".freeze
      private_constant :PACKAGE

      # Value of {Y2Storage::Filesystems::LegacyNfs#share} for a new (empty) object
      NEW_DEVICE_SHARE = ":".freeze
      private_constant :NEW_DEVICE_SHARE

      # Constructor
      #
      # @param legacy_nfs [Y2Storage::Filesystems::LegacyNfs] representation of the NFS mount to add
      #   or edit
      # @param nfs_entries [Array<Y2Storage::Filesystems::LegacyNfs>] entries used by the NfsForm to
      #   check for duplicate mount points
      def initialize(legacy_nfs, nfs_entries)
        super()
        textdomain "storage"

        @form = self.class.nfs_form_class.new(legacy_nfs, nfs_entries)
        @action = legacy_nfs.share == NEW_DEVICE_SHARE ? :add : :edit
      end

      # @macro seeDialog
      def contents
        HVSquash(
          VBox(@form, form_validator)
        )
      end

      # Form title
      #
      # @return [String]
      def title
        if @action == :add
          # TRANSLATORS: wizard title
          _("Add NFS mount")
        else
          # TRANSLATORS: wizard title
          _("Edit NFS mount")
        end
      end

      class << self
        # Whether to show the dialog
        #
        # The package yast2-nfs-client must be installed in order to properly show the dialog.
        #
        # @return [Boolean]
        def run?
          widget_exists? || install_widget
        end

        # Checks whether the NfsForm class provided by yast2-nfs-client is available
        #
        # @return [Boolean]
        def widget_exists?
          nfs_form_class
          true
        rescue LoadError, NameError
          false
        end

        # Form class provided by yast2-nfs-client
        def nfs_form_class
          require "y2nfs_client/widgets/nfs_form"
          Y2NfsClient::Widgets::NfsForm
        end

        # Installs the package that provides the required widget, if possible
        #
        # The installation requires confirmation from the user.
        #
        # @return [Boolean] true if installation succeeded, false if it was not
        #   possible to install the package or the user rejected to do it.
        def install_widget
          if in_inst_sys?
            log.info "Is not possible to install nfs-client"
            return false
          end

          pkgs = [PACKAGE]
          log.info "Trying to install #{pkgs}"
          Yast::PackageCallbacks.RegisterEmptyProgressCallbacks
          res = Yast::Package.CheckAndInstallPackages(pkgs)
          Yast::PackageCallbacks.RestorePreviousProgressCallbacks
          log.info "Installation result: #{res}"
          res
        end

        # Checks whether the partitioner is being executed in the inst-sys (i.e.
        # during system installation)
        #
        # @return [Boolean]
        def in_inst_sys?
          Yast::Stage.initial
        end
      end

      private

      # @return [CWM::CustomWidget] widget from yast2-nfs-client to collect information about the
      #   NFS mount (using a {Y2Storage::Filesystems::LegacyNfs} object).
      attr_reader :form

      # @return [FormValidator]
      def form_validator
        FormValidator.new(@form)
      end

      # Empty widget to add validations on top of the ones already performed by the
      # yast2-nfs-client widget
      class FormValidator < CWM::CustomWidget
        Yast.import "Popup"

        # Constructor
        #
        # @param form [CWM::CustomWidget]
        def initialize(form)
          super()
          textdomain "storage"

          @form = form
          @initial_share = nfs.share
        end

        # @macro seeCustomWidget
        def contents
          Empty()
        end

        # Extra validations to perform for the LegacyNfs object handled by the yast2-nfs-client form
        #
        # Note this method triggers the store of the yast2-nfs-client widget, so the LegacyNfs
        # object is updated even if these extra validations fail
        #
        # @return [Boolean]
        def validate
          @form.store
          return true unless validate_reachable?
          return true if nfs.reachable?

          # TRANSLATORS: pop-up message. %s is replaced for something like 'server:/path'
          msg = _("Test mount of NFS share '%s' failed.\nSave it anyway?") % nfs.share
          keep = Yast::Popup.YesNo(msg)
          # Save only if user confirms (bsc#450060)
          log.warn "Test mount of NFS share #{nfs.inspect} failed. Save anyway?: #{keep}"
          keep
        end

        private

        # @return [Y2Storage::Filesystems::LegacyNfs]
        def nfs
          @form.nfs
        end

        # Whether to check if the NFS share is reachable
        #
        # @return [Boolean]
        def validate_reachable?
          # Always validate new NFS entries
          return true if @initial_share == NEW_DEVICE_SHARE

          # For pre-existing entries, check only if the connection information changed
          nfs.share != @initial_share
        end
      end
    end
  end
end
