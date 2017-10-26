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
require "y2storage/dialogs/guided_setup/select_filesystem/base"
require "y2storage/filesystems/type"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog to select filesystems.
      module SelectFilesystem
        # This is the more advanced version for the NG-style proposal settings
        # that support more than just a separate home volume.
        # See also SelectFilesystem::Legacy.
        #
        class Ng < Base
          attr_reader :root_vol, :home_vol, :swap_vol, :other_volumes

          def initialize(*params)
            super
            @root_vol = find_vol("/")
            @home_vol = find_vol("/home")
            @swap_vol = find_vol("swap")
            @other_volumes = find_other_volumes

            ensure_root_vol_defaults
            ensure_swap_vol_defaults
          end

          # Enable or disable widgets for the root volume.
          # Automatically called when the user selects a value in the
          # root_fs_type combo box.
          #
          def root_fs_type_handler
            fs_type = widget_value(:root_fs_type)
            return if fs_type.nil?
            fs_type = Filesystems::Type.find(fs_type)

            enable_snapshots = fs_type.is?(:btrfs)
            enable_snapshots &&= @root_vol.snapshots_configurable? unless @root_vol.nil?
            widget_update(:snapshots, enable_snapshots, attr: :Enabled)
          end

          # next_handler and back_handler are inherited from GuidedSetup::Base

          # Event handler for other events that are not handled automatically
          # in any of the above _handler methods.
          #
          def handle_event(widget_id)
            if widget_id.to_s.start_with?("propose_")
              fs_type_widget_id = widget_id.to_s.gsub(/^propose_/, "") + "_fs_type"
              propose = widget_value(widget_id)
              widget_update(fs_type_widget_id.to_sym, propose, attr: :Enabled)
            end
          end

        protected

          # Ensure reasonable defaults for some members of the root volume
          #
          def ensure_root_vol_defaults
            return if @root_vol.nil?
            @root_vol.proposed = true # A root volume is definitely required
            using_btrfs = @root_vol.fs_type.is?(:btrfs)
            @root_vol.snapshots = using_btrfs if @root_vol.snapshots.nil?
            @root_vol.snapshots_configurable = using_btrfs if @root_vol.snapshots_configurable.nil?
          end

          # Ensure reasonable defaults for some members of the swap volume, but
          # just for the main swap volume, not just for every other one that
          # might also be there.
          #
          def ensure_swap_vol_defaults
            return if @swap_vol.nil?
            @swap_vol.adjust_by_ram ||= false
            @swap_vol.adjust_by_ram_configurable ||= true
          end

          # Return a widget term for the dialog content, i.e. all the volumes
          # and possibly some more interactive widgets.
          #
          # @return [WidgetTerm]
          #
          def dialog_content
            widgets = [root_vol_widget, home_vol_widget]
            widgets << other_volumes_widgets
            widgets << swap_vol_widget
            widgets.flatten!.compact!

            content = widgets.each_with_object(VBox()) do |widget, vbox|
              vbox << VSpacing(2) unless vbox.empty?
              vbox << widget
            end

            HVCenter(
              HSquash(
                content
              )
            )
          end

          # Return a widget term for the root volume.
          #
          # @return [WidgetTerm]
          #
          def root_vol_widget
            return nil if @root_vol.nil?
            fs_types = @root_vol.fs_types || Filesystems::Type.root_filesystems
            items = fs_types.map do |fs|
              Item(Id(fs.to_sym), fs.to_human_string, fs == @root_vol.fs_type)
            end
            VBox(
              Left(
                ComboBox(
                  Id(:root_fs_type), Opt(:notify), _("File System for Root Partition"), items
                )
              ),
              Left(
                HBox(
                  HSpacing(3),
                  Left(CheckBox(Id(:snapshots), _("Enable Snapshots"), @root_vol.snapshots?))
                )
              )
            )
          end

          # Return a widget term for the home volume.
          #
          # @return [WidgetTerm]
          #
          def home_vol_widget
            # Translators: name of the partition that holds the users' home directories (/home)
            vol_widget(@home_vol, _("Home"))
          end

          # Return a widget term for the swap volume.
          #
          # @return [WidgetTerm]
          #
          def swap_vol_widget
            return nil if @swap_vol.nil?
            return nil unless @swap_vol.adjust_by_ram_configurable?
            Left(
              CheckBox(
                Id(:enlarge_swap),
                _("Enlarge Swap for Suspend"),
                @swap_vol.adjust_by_ram?
              )
            )
          end

          # Return the widgets for the 'other' volumes, i.e. all except root, home, swap.
          #
          # @return [Array<WidgetTerm>]
          #
          def other_volumes_widgets
            @other_volumes.each_with_object([]) { |vol, widgets| widgets << vol_widget(vol) }
          end

          # Return a widget term for a volume with an optional name.
          # If not specified, use the mount point as the name.
          #
          # @param vol [VolumeSpecification]
          # @param vol_name [String]
          # @return [WidgetTerm]
          def vol_widget(vol, vol_name = nil)
            return nil if vol.nil?
            return nil unless vol.proposed? || vol.proposed_configurable?
            vol_name ||= vol.mount_point
            VBox(
              propose_widget(vol, vol_name),
              fs_type_widget(vol, vol_name)
            )
          end

          # Return a widget term for the checkbox to select if a partition should be proposed.
          # The checkbox might be disabled if the user is not allowed to change this value.
          # The idea is to show the user even in that case that the partition
          # will be created, even if he cannot prevent that.
          #
          # @param vol [VolumeSpecification]
          # @param vol_name [String]
          # @return [WidgetTerm]
          #
          def propose_widget(vol, vol_name)
            cb_opt = Opt(:notify)
            cb_opt << :disabled unless vol.proposed_configurable?
            Left(
              CheckBox(Id(propose_widget_id(vol_name)), cb_opt,
                # Translators: %1 is the name of the partition ("root", "home", "/data", ...
                Yast::Builtins.sformat(_("Propose Separate %1 Partition"), vol_name),
                vol.proposed?)
            )
          end

          # Return a widget term for a volume's filesystem type.
          #
          # @param vol [VolumeSpecification]
          # @param vol_name [String]
          # @return [WidgetTerm]
          #
          def fs_type_widget(vol, vol_name)
            return Empty() unless fs_type_user_configurable?(vol)
            fs_types = vol.fs_types || Filesystems::Type.home_filesystems
            items = fs_types.map { |fs| Item(Id(fs.to_sym), fs.to_human_string) }
            Left(
              HBox(
                HSpacing(2),
                ComboBox(
                  Id(fs_type_widget_id(vol_name)),
                  # Translators: %1 is the name of the partition ("root", "home", "/data", ...
                  Yast::Builtins.sformat(_("File System for %1 Partition"), vol_name),
                  items
                )
              )
            )
          end

          # Check if the filesystem type for a volume should be user configurable.
          #
          # @param vol [VolumeSpecification]
          # @return [Boolean]
          #
          def fs_type_user_configurable?(vol)
            return false if vol.fs_type == :swap
            return false if vol.fs_types == [:swap]
            true
          end

          # Create a normalized ID for a volume: Use its name or mount point,
          # strip any leading slash, replace any other special character with
          # an underscore and simplify underscores.
          # "/home" -> "home"
          # "/var/lib/docker" -> "var_lib_docker"
          # "any?! weird!! name__whatever" -> "any_weird_name_whatever"
          #
          # @param name [String]
          # @return [String]
          #
          def normalized_id(name)
            id = name.gsub(/[^a-zA-Z0-9_]/, "_")
            id.gsub!(/__+/, "_")
            id.gsub!(/^_/, "")
            id.gsub!(/_$/, "")
            id.downcase
          end

          # Return the widget ID of a volume's checkbox to enable or disable
          # proposing it
          #
          # @param vol_name [String]
          # @return [Symbol]
          #
          def propose_widget_id(vol_name)
            ("propose_" + normalized_id(vol_name)).to_sym
          end

          # Return the widget ID of a volume's combo box to select the
          # filesystem type
          #
          # @param vol_name [String]
          # @return [Symbol]
          #
          def fs_type_widget_id(vol_name)
            (normalized_id(vol_name) + "_fs_type").to_sym
          end

          # Initialize the interactive widgets
          #
          def initialize_widgets
            widget_update(:root_fs_type, @root_vol.fs_type.to_sym) unless @root_vol.nil?
            widget_update(:snapshots, @root_vol.snapshots?) unless @root_vol.nil?
            widget_update(:enlarge_swap, @swap_vol.adjust_by_ram?) unless @swap_vol.nil?
            root_fs_type_handler
            init_swap_vol_widgets
            init_home_vol_widgets
            init_other_volumes_widgets
          end

          # Enable or disable widgets for the swap volume
          #
          def init_swap_vol_widgets
            return if @swap_vol.nil?
            widget_update(:enlarge_swap, @swap_vol.adjust_by_ram_configurable?, attr: :Enabled)
          end

          def init_home_vol_widgets
            init_vol_widgets(@home_vol)
          end

          # Enable or disable widgets for all 'other' volumes
          #
          def init_other_volumes_widgets
            @other_volumes.each { |vol| init_vol_widgets(vol) }
          end

          # Enable or disable widgets for one volume that has a "propose" check
          # box and possibly a filesystem selection combo box (i.e. home and
          # any of the 'other' volumes)
          #
          # @param vol [VolumeSpecification]
          #
          def init_vol_widgets(vol)
            return if vol.nil?
            return unless fs_type_user_configurable?(vol)
            vol_name = vol.mount_point
            propose = widget_value(propose_widget_id(vol_name))
            combo_box_id = fs_type_widget_id(vol_name)
            widget_update(combo_box_id, propose, attr: :Enabled)
            # Make sure something is selected
            current_val = widget_value(combo_box_id)
            widget_update(combo_box_id, vol.fs_type.to_sym) if current_val.nil?
          end

          # Update the settings: Fetch the current widget values and store them
          # in the settings.
          #
          def update_settings!
            if !@root_vol.nil?
              fs_type = widget_value(:root_fs_type)
              @root_vol.fs_type = Filesystems::Type.find(fs_type) unless fs_type.nil?
              @root_vol.snapshots = widget_value(:snapshots)
            end
            if !@swap_vol.nil?
              @swap_vol.adjust_by_ram = widget_value(:enlarge_swap)
              @swap_vol.fs_type = Y2Storage::Filesystems::Type::SWAP
            end
            update_vol_settings!(@home_vol)
            @other_volumes.each { |vol| update_vol_settings!(vol) }
          end

          # Update the settings for one volume.
          # This works only for volumes that have a mount point.
          #
          # @param vol [VolumeSpecification]
          #
          def update_vol_settings!(vol)
            return if vol.nil?
            vol_name = vol.mount_point
            vol.proposed = widget_value(propose_widget_id(vol_name))
            if fs_type_user_configurable?(vol)
              fs_type = widget_value(fs_type_widget_id(vol_name))
              vol.fs_type = Filesystems::Type.find(fs_type) unless fs_type.nil?
            end
          end

          # Find a VolumeSpecification from the proposal settings based on its
          # mount point.
          #
          # @param mount_point [String]
          #
          def find_vol(mount_point)
            return nil if settings.volumes.nil?
            vol = settings.volumes.find { |v| v.mount_point == mount_point }
            found = vol.nil? ? "No" : "Found"
            log.info("#{found} volume with mount point \"#{mount_point}\" in the settings")
            vol
          end

          # Find all "other" VolumeSpecifications from the proposal settings,
          # i.e. volumes other than the standard root, home, swap volumes.
          #
          # @return [Array<VolumeSpecifications>]
          #
          def find_other_volumes
            return [] if settings.volumes.nil?
            other_vol = settings.volumes.reject { |vol| [@root_vol, @home_vol, @swap_vol].include?(vol) }
            other_vol.each do |vol|
              log.info("Found other volume with mount point \"#{vol.mount_point}\" in the settings")
            end
            other_vol
          end
        end
      end
    end
  end
end
