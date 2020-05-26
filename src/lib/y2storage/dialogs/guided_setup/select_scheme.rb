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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/base"

Yast.import "Popup"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog to select partitioning scheme.
      class SelectScheme < Base
        extend Yast::I18n

        WIDGET_LABELS = {
          # TRANSLATORS: label for the widget that allows to enable the disk encryption
          enable_disk_encryption: N_("Enable Disk Encryption"),
          # TRANSLATORS: label for the widget that allows to use separated volume groups
          use_separate_vgs:       N_("Use Separate LVM Volume Groups for Some Special Paths").freeze
        }
        private_constant :WIDGET_LABELS

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

        # This dialog is never skipped
        #
        # @return [Boolean]
        def skip?
          false
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
              enable_lvm,
              separate_vgs,
              enable_disk_encryption
            )
          )
        end

        def enable_lvm
          label =
            if settings.separate_vgs_relevant?
              _("Enable Logical Volume Management (LVM) for the Base System")
            else
              _("Enable Logical Volume Management (LVM)")
            end

          VBox(
            Left(CheckBox(Id(:lvm), label)),
            VSpacing(1)
          )
        end

        def separate_vgs
          return Empty() unless settings.separate_vgs_relevant?

          separated_volume_groups = settings.volumes.select(&:separate_vg_name)

          VBox(
            Left(
              CheckBox(
                Id(:separate_vgs),
                format(
                  # TRANSLATORS: %{widget_label} refers to the label of the widget. %{paths} is a
                  # comma separated list of paths
                  _("%{widget_label}\n(%{paths})"),
                  widget_label: WIDGET_LABELS[:use_separate_vgs],
                  paths:        separated_volume_groups.map(&:mount_point).join(", ")
                )
              )
            ),
            VSpacing(1)
          )
        end

        def enable_disk_encryption
          VBox(
            Left(CheckBox(Id(:encryption), Opt(:notify), WIDGET_LABELS[:enable_disk_encryption])),
            VSpacing(0.2),
            Left(
              HBox(
                HSpacing(2),
                Password(Id(:password), Opt(:hstretch), _("Password"))
              )
            ),
            Left(
              HBox(
                HSpacing(2),
                Password(Id(:repeat_password), Opt(:hstretch), _("Verify Password"))
              )
            )
          )
        end

        def initialize_widgets
          widget_update(:lvm, settings.use_lvm)
          widget_update(:separate_vgs, settings.separate_vgs)
          widget_update(:encryption, settings.use_encryption)
          encryption_handler(focus: false)
          return unless settings.use_encryption

          widget_update(:password, settings.encryption_password)
          widget_update(:repeat_password, settings.encryption_password)
        end

        def update_settings!
          settings.use_lvm = widget_value(:lvm)
          settings.separate_vgs = widget_value(:separate_vgs)
          password = using_encryption? ? widget_value(:password) : nil
          settings.encryption_password = password
        end

        def help_text
          help = [base_help_text]
          help << separate_vgs_help_text if settings.separate_vgs_relevant?

          help.join("\n\n")
        end

        # rubocop:disable Metrics/MethodLength
        def base_help_text
          # TRANSLATORS: Help text for the partitioning scheme (LVM / encryption)
          format(
            _(
              "<p>" \
              "Select the partitioning scheme:" \
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
              "<b>%{disk_encryption_label}</b> (with or without LVM) adds a LUKS " \
              " disk encryption layer to the partitioning setup. " \
              "Notice that you will have to enter the correct password each time " \
              "you boot the system. " \
              "</p><p>" \
              "<i>If you lose the password, there is no way to recover it, " \
              "so make sure not to lose it!</i>" \
              "</p>"
            ),
            disk_encryption_label: WIDGET_LABELS[:use_disk_encryption]
          )
          # rubocop:enable Metrics/MethodLength
        end

        def separate_vgs_help_text
          # TRANSLATORS: %{widget_label} refers to the label of the described widget
          format(
            _("<p><b>%{widget_label}:</b> indicates to the <i>Guided Setup</i> that you want " \
              "to put some of those special paths in an isolated Volume Group.</p>"),
            widget_label: WIDGET_LABELS[:use_separate_vgs]
          )
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
