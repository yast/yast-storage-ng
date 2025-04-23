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
require "y2storage/partitioning_features"
require "y2storage/encryption_authentication"

Yast.import "Popup"
Yast.import "Arch"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog to select partitioning scheme.
      class SelectScheme < Base
        include PartitioningFeatures
        extend Yast::I18n

        WIDGET_LABELS = {
          # TRANSLATORS: label for the widget that allows to enable the disk encryption
          enable_disk_encryption: N_("Enable Disk Encryption"),
          # TRANSLATORS: label for the widget that allows to use separated volume groups
          use_separate_vgs:       N_("Use Separate LVM Volume Groups for Some Special Paths").freeze,
          # TRANSLATORS: label for the widget to set authentication type for encrypted devices.
          authentication:         N_("Authentication").freeze
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
          if settings.encryption_method == EncryptionMethod::SYSTEMD_FDE
            widget_update(:authentication, using_encryption?, attr: :Enabled)
          end
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
                  "%{widget_label}\n(%{paths})",
                  widget_label: _(WIDGET_LABELS[:use_separate_vgs]),
                  paths:        separated_volume_groups.map(&:mount_point).join(", ")
                )
              )
            ),
            VSpacing(1)
          )
        end

        def authentication
          return Empty() unless settings.encryption_method == EncryptionMethod::SYSTEMD_FDE

          items = Y2Storage::EncryptionAuthentication.all.map do |auth|
            Item(Id(auth.value), auth.name, auth.value == settings.encryption_authentication)
          end

          Left(
            HBox(
              HSpacing(2),
              ComboBox(Id(:authentication), Opt(:hstretch), _(WIDGET_LABELS[:authentication]), items)
            )
          )
        end

        def enable_disk_encryption
          VBox(
            Left(CheckBox(Id(:encryption), Opt(:notify), _(WIDGET_LABELS[:enable_disk_encryption]))),
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
            ),
            authentication
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
          return unless settings.encryption_method == EncryptionMethod::SYSTEMD_FDE

          widget_update(:authentication,
            settings.encryption_authentication.value)
        end

        def update_settings!
          settings.use_lvm = widget_value(:lvm)
          settings.separate_vgs = widget_value(:separate_vgs)
          password = using_encryption? ? widget_value(:password) : nil
          settings.encryption_password = password
          return unless settings.encryption_method == EncryptionMethod::SYSTEMD_FDE

          settings.encryption_authentication = EncryptionAuthentication.find(
            widget_value(:authentication)
          )
        end

        def help_text
          help = [base_help_text]
          help << separate_vgs_help_text if settings.separate_vgs_relevant?
          help << authentication_help_text if settings.encryption_method == EncryptionMethod::SYSTEMD_FDE

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
              "<b>%{disk_encryption_label}</b> (with or without LVM) adds a %{encrption_method} " \
              " disk encryption layer to the partitioning setup. " \
              "Notice that you will have to enter the correct password each time " \
              "you boot the system. " \
              "</p><p>" \
              "<i>If you lose the password, there is no way to recover it, " \
              "so make sure not to lose it!</i>" \
              "</p>"
            ),
            disk_encryption_label: _(WIDGET_LABELS[:enable_disk_encryption]),
            encrption_method:      settings.encryption_method.to_human_string
          )
          # rubocop:enable Metrics/MethodLength
        end

        def authentication_help_text
          # TRANSLATORS: %{widget_label} refers to the label of the described widget
          format(_("<p><b>%{widget_label}:</b> Which method will be used for unlocking the devices:" \
                   "</p><ul>" \
                   "<li><i>Only password: </i>Password is required.</li>" \
                   "<li><i>TPM2: </i>A crypto-device that is already present in your system.</li>" \
                   "<li><i>TPM2 and PIN: </i>Like TPM2, but a password must be enter together.</li>" \
                   "<li><i>FIDO2: </i>External key device.</li>" \
                   "</ul>"), widget_label: _(WIDGET_LABELS[:authentication]))
        end

        def separate_vgs_help_text
          # TRANSLATORS: %{widget_label} refers to the label of the described widget
          format(_("<p><b>%{widget_label}:</b> indicates to the <i>Guided Setup</i> that you want " \
                   "to put some of those special paths in an isolated Volume Group.</p>"),
            widget_label: _(WIDGET_LABELS[:use_separate_vgs]))
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
