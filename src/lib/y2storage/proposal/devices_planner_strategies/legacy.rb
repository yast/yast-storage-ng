# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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

require "y2storage/proposal/devices_planner_strategies/base"

module Y2Storage
  module Proposal
    module DevicesPlannerStrategies
      # Class to generate the list of planned devices of a proposal when
      # the format of propsal settings is legacy.
      class Legacy < Base
        MIN_SWAP_SIZE = DiskSize.MiB(512)
        MAX_SWAP_SIZE = DiskSize.GiB(2) # This is also DEFAULT_SWAP_SIZE
        SWAP_WEIGHT = 100 # Importance of swap if low free disk space

        # List of devices (read: partitions or volumes) that need to be
        # created to satisfy the settings.
        #
        # @see Base#planned_devices
        #
        # @param target [Symbol] :desired, :min
        # @return [Array<Planned::Device>]
        def planned_devices(target)
          @target = target
          devices = base_devices + additional_devices
          remove_shadowed_subvolumes(devices)
          devices
        end

      protected

        # Minimal set of devices that is needed to decide if a bootable
        # system can be installed
        #
        # This includes "/" and the devices needed for booting
        #
        # @return [Array<Planned::Device>]
        def base_devices
          root = root_device
          planned_boot_devices([root]) + [root]
        end

        # Additional devices not needed for booting, like swap and /home
        #
        # @return [Array<Planned::Device>]
        def additional_devices
          devices = [swap_device]
          devices << home_device if @settings.use_separate_home
          devices
        end

        # Device to host the swap space according to the settings.
        def swap_device
          min_size = max_size = MAX_SWAP_SIZE
          if settings.enlarge_swap_for_suspend
            min_size = max_size = [ram_size, max_size].max
          elsif @target == :min
            min_size = MIN_SWAP_SIZE
            # leave max_size alone so any leftover free space can be distributed
            # to swap, too according to SWAP_WEIGHT
          end
          if settings.use_lvm
            swap_lv(min_size, max_size)
          else
            swap_partition(min_size, max_size)
          end
        end

        def swap_lv(min_size, max_size)
          lv = Planned::LvmLv.new("swap", Filesystems::Type::SWAP)
          lv.logical_volume_name = "swap"
          lv.min_size = min_size
          lv.max_size = max_size
          lv.weight = SWAP_WEIGHT
          lv
        end

        def swap_partition(min_size, max_size)
          part = Planned::Partition.new("swap", Filesystems::Type::SWAP)
          part.encryption_password = settings.encryption_password
          # NOTE: Enforcing the re-use of an existing partition limits the options
          # to propose a valid distribution of the planned partitions. For swap we
          # already have mechanisms to reuse UUIDs and labels, so maybe is smarter
          # to never reuse partitions as-is.
          reuse = reusable_swap(max_size)
          if reuse
            part.reuse_name = reuse.name
          else
            part.min_size = min_size
            part.max_size = max_size
            part.weight = SWAP_WEIGHT
          end
          part
        end

        # Planned device to hold "/" according to the settings.
        def root_device
          if settings.use_lvm
            root_vol = Planned::LvmLv.new("/", @settings.root_filesystem_type)
          else
            root_vol = Planned::Partition.new("/", @settings.root_filesystem_type)
            root_vol.disk = @settings.root_device
            root_vol.encryption_password = @settings.encryption_password
          end
          root_vol.weight   = @settings.root_space_percent
          root_vol.max_size = @settings.root_max_size
          root_vol.min_size =
            if @target == :min || root_vol.max_size.unlimited?
              @settings.root_base_size
            else
              root_vol.max_size
            end
          setup_btrfs(root_vol)
          root_vol
        end

        def setup_btrfs(planned_vol)
          return unless planned_vol.btrfs?

          if settings.use_snapshots && planned_vol.root?
            log.info "Enabling snapshots for '/'"
            planned_vol.snapshots = true
            adjust_btrfs_sizes(planned_vol)
          end

          init_btrfs_subvolumes(planned_vol)
        end

        # Sizes have to be adjusted only when using snapshots
        def adjust_btrfs_sizes(planned_device)
          multiplicator = 1.0 + settings.btrfs_increase_percentage / 100.0
          log.info "Increasing root filesystem size for snapshots (#{multiplicator})"
          planned_device.min_size *= multiplicator
          planned_device.max_size *= multiplicator
        end

        def init_btrfs_subvolumes(planned_device)
          return unless settings.subvolumes

          planned_device.default_subvolume = settings.btrfs_default_subvolume || ""
          planned_device.subvolumes = settings.subvolumes
          log.info "Adding Btrfs subvolumes: \n#{planned_device.subvolumes}"
        end

        # Planned device to hold "/home" according to the settings.
        def home_device
          if settings.use_lvm
            home_vol = Planned::LvmLv.new("/home", settings.home_filesystem_type)
          else
            home_vol = Planned::Partition.new("/home", settings.home_filesystem_type)
            home_vol.encryption_password = settings.encryption_password
          end
          home_vol.max_size = settings.home_max_size
          home_vol.min_size =
            if @target == :min
              settings.root_base_size
            else
              settings.home_min_size
            end
          home_vol.weight = 100.0 - settings.root_space_percent
          home_vol
        end
      end
    end
  end
end
