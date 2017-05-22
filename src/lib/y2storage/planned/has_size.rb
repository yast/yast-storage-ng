#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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
require "y2storage/disk_size"

module Y2Storage
  module Planned
    # Mixing enabling some classes of planned devices to specify the size of the
    # final device in a flexible way.
    # @see Planned::Device
    module HasSize
      # @return [DiskSize] definitive size of the device
      attr_accessor :size

      # @!attribute min_size
      #   minimum acceptable size
      #
      #   @return [DiskSize] zero for reused volumes
      attr_writer :min_size

      # @return [DiskSize] maximum acceptable size
      attr_accessor :max_size

      # @return [Float] factor used to distribute the extra space
      #   between devices
      attr_accessor :weight

      # Initializations of the mixin, to be called from the class constructor.
      def initialize_has_size
        self.size     = DiskSize.zero
        self.min_size = DiskSize.zero
        self.max_size = DiskSize.unlimited
        self.weight   = 0
      end

      def min_size
        # No need to provide space for reused volumes
        (respond_to?(:reuse) && reuse) ? DiskSize.zero : @min_size
      end

      alias_method :min, :min_size
      alias_method :max, :max_size
      alias_method :min=, :min_size=
      alias_method :max=, :max_size=

      # Class methods for the mixin
      module ClassMethods
        include Yast::Logger

        # Returns a copy of the list in which the given space has been distributed
        # among the devices, distributing the extra space (beyond the min size)
        # according to the weight and max size of each device.
        #
        # @raise [RuntimeError] if the given space is not enough to reach the min
        #     size for all devices
        #
        # If the optional argument rounding is used, space will be distributed
        # always in blocks of the specified size.
        #
        # @param devices [Array] devices to distribute the space among. All of
        #     them should be of a class including this mixin.
        # @param space_size [DiskSize]
        # @param rounding [DiskSize, nil] min block size to distribute. Mainly used
        #     to distribute space among LVs honoring the PE size of the LVM
        # @param min_grain [DiskSize, nil] minimal grain of the disk where the space
        #     is located. It only makes sense when distributing space among
        #     partitions.
        # @return [Array] list containing devices with an adjusted value
        #     for Planned::HasSize#size
        def distribute_space(devices, space_size, rounding: nil, min_grain: nil)
          raise RuntimeError if space_size < DiskSize.sum(devices.map(&:min))

          rounding ||= min_grain
          rounding ||= DiskSize.new(1)

          new_list = devices.map do |device|
            new_dev = device.dup
            new_dev.size = device.min_size.ceil(rounding)
            new_dev
          end
          adjust_size_to_last_slot!(new_list.last, space_size, min_grain) if min_grain

          extra_size = space_size - DiskSize.sum(new_list.map(&:size))
          unused = distribute_extra_space!(new_list, extra_size, rounding)
          new_list.last.size += unused if min_grain && unused < min_grain

          new_list
        end

      protected

        # @return [DiskSize] Surplus space that could not be distributed
        def distribute_extra_space!(candidates, extra_size, rounding)
          while distributable?(extra_size, rounding)
            candidates = extra_space_candidates(candidates)
            return extra_size if candidates.empty?
            return extra_size if total_weight(candidates).zero?
            log.info("Distributing #{extra_size} extra space among #{candidates.size} devices")

            assigned_size = DiskSize.zero
            total_weight = total_weight(candidates)
            candidates.each do |dev|
              device_extra = device_extra_size(dev, extra_size, total_weight, assigned_size, rounding)
              dev.size += device_extra
              log.info("Distributing #{device_extra} to #{dev}; now #{dev.size}")
              assigned_size += device_extra
            end
            extra_size -= assigned_size
          end
          log.info("Could not distribute #{extra_size}") unless extra_size.zero?
          extra_size
        end

        # Devices that may grow when distributing the extra space
        #
        # @param [Array]
        # @return [Array]
        def extra_space_candidates(devices)
          devices.select { |dev| dev.size < dev.max_size }
        end

        # Extra space to be assigned to a device
        #
        # @param device [Object] device (of a class including this mixin) to enlarge
        # @param total_size [DiskSize] free space to be distributed among involved devices
        # @param total_weight [Float] sum of the weights of all involved devices
        # @param assigned_size [DiskSize] space already distributed to other devices
        # @param rounding [DiskSize] size to round up
        #
        # @return [DiskSize]
        def device_extra_size(device, total_size, total_weight, assigned_size, rounding)
          available_size = total_size - assigned_size

          extra_size = total_size * (device.weight.to_f / total_weight)
          extra_size = extra_size.ceil(rounding)
          extra_size = available_size.floor(rounding) if extra_size > available_size

          new_size = extra_size + device.size
          if new_size > device.max_size
            # Increase just until reaching the max size
            device.max_size - device.size
          else
            extra_size
          end
        end

        def distributable?(size, rounding)
          size >= rounding
        end

        def adjust_size_to_last_slot!(device, space_size, min_grain)
          adjusted_size = adjusted_size_after_ceil(device, space_size, min_grain)
          device.size = adjusted_size unless adjusted_size < device.min_size
        end

        def adjusted_size_after_ceil(device, space_size, min_grain)
          mod = space_size % min_grain
          last_slot_size = mod.zero? ? min_grain : mod
          return device.size if last_slot_size == min_grain

          missing = min_grain - last_slot_size
          device.size - missing
        end

        # Total sum of all weights of the planned devices
        #
        # @return [Float]
        def total_weight(devices)
          devices.map(&:weight).reduce(0, :+)
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
