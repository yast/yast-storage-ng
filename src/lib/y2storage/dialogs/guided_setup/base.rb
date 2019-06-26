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

Yast.import "Report"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Base class for guided setup dialogs.
      class Base < ::UI::InstallationDialog
        def initialize(guided_setup)
          textdomain "storage"

          super()
          log.info "#{self.class}: start with #{guided_setup.settings.inspect}"
          @guided_setup = guided_setup
        end

        # Whether the dialog should be skipped.
        def skip?
          false
        end

        # Actions to do before skipping the dialog.
        # Guided setup controller calls this method when necessary.
        def before_skip
          nil
        end

        # Only continues if selected settings are valid. In other case,
        # an error dialog is expected.
        def next_handler
          if valid?
            update_settings!
            log.info "#{self.class}: return :next with #{settings.inspect}"
            super
          end
        end

        def back_handler
          log.info "#{self.class}: return :back with #{settings.inspect}"
          super
        end

        def settings
          guided_setup.settings
        end

        def analyzer
          guided_setup.analyzer
        end

        # Disk label used by dialogs.
        # name, size, [USB] and installed systems, for example:
        #   "/dev/sda, 10.00 GiB, Windows, OpenSUSE"
        #   "/dev/sdb, 8.00 GiB, USB"
        # @return [String]
        def disk_label(disk)
          data = [disk.name, disk.size.to_human_string]
          data += disk_type_labels(disk)
          data += analyzer.installed_systems(disk)
          data.join(", ")
        end

        protected

        # Controller object needed to access to settints and pre-calculated data.
        attr_reader :guided_setup

        def create_dialog
          super
          initialize_widgets
          true
        end

        # To be implemented by derived classes, if needed
        def initialize_widgets
          nil
        end

        # Can be redefined by derived classes to indicate whether
        # selected options are valid.
        def valid?
          true
        end

        # Should be implemented by derived classes.
        def update_settings!
          nil
        end

        # FIXME: it should include help of each setup
        def help_text
          ""
        end

        # Helper to get widget value
        def widget_value(id, attr: :Value)
          Yast::UI.QueryWidget(Id(id), attr)
        end

        # Helper to set widget value
        def widget_update(id, value, attr: :Value)
          Yast::UI.ChangeWidget(Id(id), attr, value)
        end

        # Labels to help indentifying some kind of disks, like USB ones
        #
        # @see #disk_label
        #
        # @param disk [BlkDevice]
        # @return [Array<String>]
        def disk_type_labels(disk)
          return [] unless disk.respond_to?(:transport)

          trans = transport_label(disk.transport)
          trans.empty? ? [] : [trans]
        end

        # Label for the given transport to be displayed in the dialogs
        #
        # @see #disk_type_labels
        #
        # @param transport [DataTransport]
        # @return [String] empty string if the transport is not worth mentioning
        def transport_label(transport)
          if transport.is?(:usb)
            _("USB")
          elsif transport.is?(:sbp)
            _("IEEE 1394")
          else
            ""
          end
        end
      end
    end
  end
end
