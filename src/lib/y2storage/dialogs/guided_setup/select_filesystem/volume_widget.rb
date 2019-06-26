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

module Y2Storage
  module Dialogs
    class GuidedSetup
      module SelectFilesystem
        # Class used in {SelectFilesystem::Ng} to draw each widget representing
        # a single volume and to handle its UI events.
        #
        # That dialog is basically a collection of such widgets, one for every
        # volume that can be configured.
        class VolumeWidget
          include Yast::UIShortcuts
          include Yast::I18n

          # @param settings [ProposalSettings] see {#settings}
          # @param index [Integer] see {#index}
          def initialize(settings, index)
            textdomain "storage"

            @settings = settings
            @index = index
            @volume = settings.volumes[index]
          end

          # Widget term for the volume, including widgets for everything the
          # user can configure
          #
          # @return [WidgetTerm]
          def content
            terms = []
            header = volume.proposed_configurable? ? proposed_term : header_term
            terms << Left(header)
            terms << indented(fs_type_term) if volume.fs_type_configurable?
            terms << indented(snapshots_term) if volume.snapshots_configurable?
            terms << indented(adjust_by_ram_term) if volume.adjust_by_ram_configurable?
            VBox(*terms)
          end

          # Handles UI event, updating this widget if needed
          def handle(event)
            case event.to_s
            when proposed_widget_id
              proposed_handler
            when fs_type_widget_id
              fs_type_handler
            end
          end

          # Initialize the widget status
          def init
            proposed_handler
          end

          # Updates the volume with the values from the UI
          def store
            volume.proposed = proposed?

            if volume.fs_type_configurable?
              fs_type = Yast::UI.QueryWidget(Id(fs_type_widget_id), :Value)
              fs_type = Filesystems::Type.find(fs_type)
              volume.fs_type = fs_type
            end

            if volume.snapshots_configurable?
              volume.snapshots = Yast::UI.QueryWidget(Id(snapshots_widget_id), :Value)
            end

            if volume.adjust_by_ram_configurable?
              volume.adjust_by_ram = Yast::UI.QueryWidget(Id(adjust_by_ram_widget_id), :Value)
            end

            nil
          end

          protected

          # Proposal settings being defined by the user
          # @return [ProposalSettings]
          attr_reader :settings

          # Volume specification to be configured by the user
          # @return [VolumeSpecification]
          attr_reader :volume

          # Position of #volume within the volumes list at #settings.
          #
          # Useful to relate UI elements to the corresponding volume
          attr_reader :index

          # Returns the passed term enclosed in some extra ones to make it
          # appear indented in the UI
          #
          # @return [WidgetTerm]
          def indented(term)
            Left(HBox(HSpacing(2), term))
          end

          # Widget term for the title of the volume in case it's always
          # proposed
          #
          # @return [WidgetTerm]
          def header_term
            text = settings.lvm ? header_for_lvm : header_for_partition
            Label(text)
          end

          # @see #header_term
          def header_for_lvm
            case volume.mount_point
            when "/"
              # TRANSLATORS: "Volume" refers to an LVM logical volume.
              _("Settings for the Root Volume")
            when "/home"
              # TRANSLATORS: "Volume" refers to an LVM logical volume.
              _("Settings for the Home Volume")
            when "swap"
              # TRANSLATORS: "Volume" refers to an LVM logical volume.
              _("Settings for Swap Volume")
            when nil
              # TRANSLATORS: "Volume" refers to an LVM logical volume and
              # "Additional" implies it will be created but not mounted
              _("Settings for Additional Volume")
            else
              # TRANSLATORS: "Volume" refers to a LVM logical volume. %s is a mount point.
              _("Settings for the %s Volume") % volume.mount_point
            end
          end

          # @see #header_term
          def header_for_partition
            case volume.mount_point
            when "/"
              _("Settings for the Root Partition")
            when "/home"
              _("Settings for the Home Partition")
            when "swap"
              _("Settings for Swap Partition")
            when nil
              # TRANSLATORS: "Additional" because it will be created but not mounted
              _("Settings for Additional Partition")
            else
              # TRANSLATORS: %s is a mount point (e.g. /var/lib)
              _("Settings for the %s Partition") % volume.mount_point
            end
          end

          # Return a widget term for the checkbox to select if the volume
          # should be proposed.
          #
          # @return [WidgetTerm]
          def proposed_term
            text = settings.lvm ? proposed_label_for_lvm : proposed_label_for_partition
            CheckBox(Id(proposed_widget_id), Opt(:notify), text, volume.proposed?)
          end

          # @see #proposed_term
          def proposed_label_for_lvm
            case volume.mount_point
            when "/home"
              # TRANSLATORS: "Volume" refers to a LVM logical volume.
              _("Propose Separate Home Volume")
            when "swap"
              # TRANSLATORS: "Volume" refers to a LVM logical volume.
              _("Propose Separate Swap Volume")
            when nil
              # TRANSLATORS: "Volume" refers to an LVM logical volume and
              # "Additional" implies it will be created but not mounted
              _("Propose Additional Volume")
            else
              # TRANSLATORS: "Volume" refers to a LVM logical volume. %s is a mount point.
              _("Propose Separate %s Volume") % volume.mount_point
            end
          end

          # @see #proposed_term
          def proposed_label_for_partition
            case volume.mount_point
            when "/home"
              _("Propose Separate Home Partition")
            when "swap"
              _("Propose Separate Swap Partition")
            when nil
              # TRANSLATORS: "Additional" because it will be created but not mounted
              _("Propose Additional Partition")
            else
              # TRANSLATORS: %s is a mount point (e.g. /var/lib)
              _("Propose Separate %s Partition") % volume.mount_point
            end
          end

          # Return a widget term for the volume's filesystem type.
          #
          # @return [WidgetTerm]
          def fs_type_term
            items = volume.fs_types.map do |fs|
              Item(Id(fs.to_sym), fs.to_human_string, volume.fs_type == fs)
            end

            ComboBox(Id(fs_type_widget_id), Opt(:notify), _("File System Type"), items)
          end

          # Check box for enabling snapshots
          #
          # @return [WidgetTerm]
          def snapshots_term
            CheckBox(Id(snapshots_widget_id), _("Enable Snapshots"), volume.snapshots?)
          end

          # Check box for enlarging to RAM size
          #
          # @return [WidgetTerm]
          def adjust_by_ram_term
            text = volume.swap? ? _("Enlarge to RAM Size for Suspend") : _("Enlarge to RAM size")
            CheckBox(Id(adjust_by_ram_widget_id), text, volume.adjust_by_ram?)
          end

          # Handler to be executed when the user selects a filesystem type for
          # the volume
          def fs_type_handler
            fs_type = Yast::UI.QueryWidget(Id(fs_type_widget_id), :Value)
            return unless fs_type

            fs_type = Filesystems::Type.find(fs_type)
            set_widget_enabled(:snapshots, proposed? && fs_type.is?(:btrfs))
          end

          # Handler to be executed when the user changes the check box for
          # enabling/disabling the volume
          def proposed_handler
            set_widget_enabled(:adjust_by_ram, proposed?)
            set_widget_enabled(:fs_type, proposed?)
            fs_type_handler
          end

          # Enables or disabled a given widget if it exists
          def set_widget_enabled(widget, value)
            return unless volume.public_send(:"#{widget}_configurable?")

            Yast::UI.ChangeWidget(Id(send(:"#{widget}_widget_id")), :Enabled, value)
          end

          # Whether the volume will be proposed or not, based on the volume
          # definition and the current status of the UI
          def proposed?
            return volume.proposed unless volume.proposed_configurable?

            Yast::UI.QueryWidget(Id(proposed_widget_id), :Value)
          end

          # Normalized ID for the volume
          #
          # @return [String]
          def normalized_id
            @normalized_id ||= "vol_#{index}"
          end

          # Return the widget ID of the volume's checkbox to enable or disable
          # proposing it
          #
          # @return [String]
          def proposed_widget_id
            normalized_id + "_proposed"
          end

          # Return the widget ID of the volume's combo box to select the
          # filesystem type
          #
          # @return [String]
          def fs_type_widget_id
            normalized_id + "_fs_type"
          end

          # Widget ID of the volume's check box to enable snapshots
          #
          # @return [String]
          def snapshots_widget_id
            normalized_id + "_snapshots"
          end

          # Widget ID of the volume's check box to enlarge to RAM
          #
          # @return [String]
          def adjust_by_ram_widget_id
            normalized_id + "_adjust_by_ram"
          end
        end
      end
    end
  end
end
