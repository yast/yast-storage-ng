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
    # Calculates the proposal settings to be used in the next proposal attempt.
    class GuidedSetup < ::UI::InstallationDialog
      # @return [ProposalSettings] settings specified by the user
      attr_reader :settings

      def initialize(settings)
        log.info "GuidedSetup dialog: start with #{settings.inspect}"

        super()
        textdomain "storage-ng"
        @settings = settings.dup
      end

      def next_handler
        adjust_settings_to_mode
        log.info "GuidedSetup dialog: return :next with #{settings.inspect}"
        super
      end

    protected

      def dialog_title
        _("Guided Partitioning Setup")
      end

      def dialog_content
        MarginBox(
          2, 1,
          RadioButtonGroup(
            Id(:mode),
            VBox(
              Left(RadioButton(Id(:mode_partition), _("Partition-based"), partition_selected?)),
              VSpacing(1),
              Left(RadioButton(Id(:mode_lvm), _("LVM-based"), lvm_selected?)),
              VSpacing(1),
              Left(RadioButton(Id(:mode_encrypted), _("Encrypted LVM-based"), encrypted_selected?)),
              VSpacing(1),
              Left(Password(Id(:encryption_password), _("Enter encrytion password")))
            )
          )
        )
      end

      def partition_selected?
        !settings.use_lvm
      end

      def lvm_selected?
        settings.use_lvm && settings.encryption_password.nil?
      end

      def encrypted_selected?
        settings.use_lvm && !settings.encryption_password.nil?
      end

      def adjust_settings_to_mode
        case Yast::UI.QueryWidget(Id(:mode), :CurrentButton)
        when :mode_partition
          settings.use_lvm = false
        when :mode_lvm
          settings.use_lvm = true
          settings.encryption_password = nil
        when :mode_encrypted
          settings.use_lvm = true
          settings.encryption_password = Yast::UI.QueryWidget(Id(:encryption_password), :Value)
        end
      end

      def help_text
        _(
          "<p>\n" \
          "TODO: this dialog is just temporary. " \
          "Hopefully it will end up including several steps.</p>"
        )
      end
    end
  end
end
