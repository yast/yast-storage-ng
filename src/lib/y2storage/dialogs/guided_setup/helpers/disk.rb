# Copyright (c) [2019] SUSE LLC
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

module Y2Storage
  module Dialogs
    class GuidedSetup
      module Helpers
        # Helper class to generate the label of a disk
        class Disk
          include Yast::I18n

          # Constructor
          #
          # @param analyzer [Y2Storage::DiskAnalayzer]
          def initialize(analyzer)
            textdomain "storage"

            @analyzer = analyzer
          end

          # Disk label used by dialogs
          #
          # The label has the form: "NAME, SIZE, [USB], INSTALLED_SYSTEMS".
          #
          # Examples:
          #
          #   "/dev/sda, 10.00 GiB, Windows, OpenSUSE"
          #   "/dev/sdb, 8.00 GiB, USB"
          #
          # @return [String]
          def label(disk)
            data = [disk.name, disk.size.to_human_string]
            data += type_labels(disk)
            data += analyzer.installed_systems(disk)
            data.join(", ")
          end

          private

          # @return [Y2Storage::DiskAnalyzer]
          attr_reader :analyzer

          # Labels to help indentifying some kind of disks, like USB ones
          #
          # @see #label
          #
          # @param disk [BlkDevice]
          # @return [Array<String>]
          def type_labels(disk)
            return [] unless disk.respond_to?(:transport)

            trans = transport_label(disk.transport)
            trans.empty? ? [] : [trans]
          end

          # Label for the given transport to be displayed in the dialogs
          #
          # @see #type_labels
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
end
