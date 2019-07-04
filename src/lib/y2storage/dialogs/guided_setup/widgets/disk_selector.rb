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
# with this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/widgets/base"

module Y2Storage
  module Dialogs
    class GuidedSetup
      module Widgets
        # Widget to select a disk for a volume set
        class DiskSelector < Base
          # @param index [Integer]
          # @param settings [Y2Storage::ProposalSettings]
          # @param candidate_disks [Array<Y2Storage::Device>]
          # @param disk_helper [Helpers::Disk]
          def initialize(index, settings, candidate_disks: [], disk_helper: nil)
            super(widget_id, settings)

            textdomain "storage"

            @index           = index
            @settings        = settings
            @volume_set      = settings.volumes_sets[index]
            @volumes         = volume_set.volumes
            @candidate_disks = candidate_disks
            @disk_helper     = disk_helper
          end

          # Widget term for the volume, including widgets for everything the
          # user can configure
          #
          # @return [Yast::Term]
          def content
            VBox(
              Left(label),
              Left(
                ComboBox(
                  Id(widget_id),
                  "",
                  disk_items
                )
              )
            )
          end

          # Updates the volume with the values from the UI
          def store
            volume_set.device = value

            nil
          end

          private

          # Proposal settings being defined by the user
          # @return [ProposalSettings]
          attr_reader :settings

          # @return [Helpers::Disk]
          attr_reader :disk_helper

          # Available disks
          # @return [Array<Disk>]
          attr_reader :candidate_disks

          # Volume specification set to be configured by the user
          # @return [VolumeSpecificationSet]
          attr_reader :volume_set

          # Volume specifications in the set
          # @return [Array<VolumeSpecification>]
          attr_reader :volumes

          # Position of #volume_set within the volumes_sets list at #settings.
          #
          # Useful to relate UI elements to the corresponding volume
          attr_reader :index

          # The id for the widget, based in its position within the settings
          # @return [String]
          def widget_id
            "disk_for_volume_set_#{index}"
          end

          # Items for the selector
          # @return [Array<Yast::Term>]
          def disk_items
            candidate_disks.map do |disk|
              selected   = volume_set.device == disk.name
              disk_label = disk_helper ? disk_helper.label(disk) : disk.name

              Item(Id(disk.name), disk_label, selected)
            end
          end

          # Widget term for the title of the volume in case it's always
          # proposed
          #
          # @return [Yast::Term]
          def label
            text =
              case volume_set.type
              when :lvm
                _("Disk for the system LVM")
              when :separate_lvm
                # TRANSLATORS: %{vg_name} is the volume group name (e.g. vg-spacewalk)
                format(_("Disk for %{vg_name} Volume Group"), vg_name: volume_set.vg_name)
              when :partition
                label_for_partition
              end

            Label(Id("label_of_#{widget_id}"), text)
          end

          # @see #header_term
          def label_for_partition
            mount_point = volumes.first.mount_point

            case mount_point
            when "/"
              _("Disk for the Root Partition")
            when "/home"
              _("Disk for the Home Partition")
            when "swap"
              _("Disk for Swap Partition")
            when nil
              # TRANSLATORS: "Additional" because it will be created but not mounted
              _("Disk for Additional Partition")
            else
              # TRANSLATORS: %{mount_point} is a mount point (e.g. /var/lib)
              format(_("Disk for the %{mount_point} Partition"), mount_point: mount_point)
            end
          end
        end
      end
    end
  end
end
