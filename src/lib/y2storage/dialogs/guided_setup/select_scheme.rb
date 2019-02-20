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
require "y2storage/dialogs/guided_setup/base"

Yast.import "Popup"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog to select partitioning scheme.
      class SelectScheme < Base
        def initialize(*params)
          textdomain "storage"
          @passwd_checker = EncryptPasswordChecker.new
          super
        end

        # Handler for :encryption check box.
        # @param focus [Boolean] whether password field should be focused
        def encryption_handler(focus: true)
          widget_update(:password, using_encryption?, attr: :Enabled)
          widget_update(:repeat_password, using_encryption?, attr: :Enabled)
          return unless focus && using_encryption?
          Yast::UI.SetFocus(Id(:password))
        end

        # This dialog is skipped when the settings are not editable
        #
        # @see GuidedSetup#allowed?
        #
        # @return [Boolean]
        def skip?
          !guided_setup.allowed?
        end

      protected

        # @return [EncryptPasswordChecker]
        attr_reader :passwd_checker

        def close_dialog
          passwd_checker.tear_down
          super
        end

        def dialog_title
          _("Partitioning Scheme")
        end

        def dialog_content
          HSquash(
            VBox(
              Left(CheckBox(Id(:lvm), _("Enable Logical Volume Management (LVM)"))),
              VSpacing(1),
              Left(CheckBox(Id(:encryption), Opt(:notify), _("Enable Disk Encryption"))),
              VSpacing(0.2),
              Left(
                HBox(
                  HSpacing(2),
                  Password(Id(:password), _("Password"))
                )
              ),
              Left(
                HBox(
                  HSpacing(2),
                  Password(Id(:repeat_password), _("Verify Password"))
                )
              )
            )
          )
        end

        def initialize_widgets
          widget_update(:lvm, settings.use_lvm)
          widget_update(:encryption, settings.use_encryption)
          encryption_handler(focus: false)
          if settings.use_encryption
            widget_update(:password, settings.encryption_password)
            widget_update(:repeat_password, settings.encryption_password)
          end
        end

        def update_settings!
          settings.use_lvm = widget_value(:lvm)
          password = using_encryption? ? widget_value(:password) : nil
          settings.encryption_password = password
        end

        # rubocop:disable Metrics/MethodLength
        def help_text
          # TRANSLATORS: Help text for the partitioning scheme (LVM / encryption)
          _(
            "<p>" \
            "Select the parititioning scheme:" \
            "</p><p>" \
            "<ul>" \
            "<li>Plain partitions (no LVM), the simple traditional way</li>" \
            "<li>LVM (Logical Volume Management): " \
            "<p>" \
            "This is a more flexible way of managing disk space. " \
            "</p><p>" \
            "You can spread single filesystems over multiple disks and add " \
            "(or, to some extent, remove) disks later as necessary. " \
            "</p><p>" \
            "You define PVs (Physical Volumes) from partitions or whole disks " \
            "and combine them into VGs (Volume Groups) that serve as storage " \
            "pools. You can create LVs (logical volumes) to create filesystems " \
            "(Btrfs, Ext2/3/4, XFS) on." \
            "</p><p>" \
            "In this <i>Guided Setup</i>, all this is done for you for the " \
            "standard filesystem layout if you check <b>Enable LVM</b>." \
            "</li>" \
            "</ul>" \
            "</p><p>" \
            "<b>Enable Disk Encryption</b> (with or without LVM) adds a LUKS " \
            " disk encryption layer to the partitioning setup. " \
            "Notice that you will have to enter the correct password each time " \
            "you boot the system. " \
            "</p><p>" \
            "<i>If you lose the password, there is no way to recover it, " \
            "so make sure not to lose it!</i>" \
            "</p>"
          )
          # rubocop:enable Metrics/MethodLength
        end

      private

        def valid?
          return true unless using_encryption?

          valid_password? && good_password?
        end

        def using_encryption?
          widget_value(:encryption)
        end

        def valid_password?
          msg = passwd_checker.error_msg(
            widget_value(:password), widget_value(:repeat_password)
          )
          return true if msg.nil?

          Yast::Report.Warning(msg)
          false
        end

        # User has the last word to decide whether to use a weak password.
        def good_password?
          message = passwd_checker.warning_msg(widget_value(:password))
          return true if message.nil?

          popup_text = message + "\n\n" + _("Really use this password?")
          Yast::Popup.AnyQuestion(
            "",
            popup_text,
            Yast::Label.YesButton,
            Yast::Label.NoButton,
            :focus_yes
          )
        end
      end
    end
  end
end
