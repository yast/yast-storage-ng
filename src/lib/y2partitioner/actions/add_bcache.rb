# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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
require "yast/i18n"
require "yast2/popup"
require "y2storage/bcache"
require "y2partitioner/dialogs/bcache"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Actions
    # Action for adding a bcache device
    class AddBcache
      include Yast::I18n

      def initialize
        textdomain "storage"
      end

      # Runs a dialog for adding a bcache and also modifies the device graph if the user
      # confirms the dialog.
      #
      # @return [Symbol] :back, :finish
      def run
        return :back unless validate

        dialog = Dialogs::Bcache.new(suitable_backing_devices, suitable_caching_devices)

        create_device(dialog) if dialog.run == :next

        :finish
      end

    private

      # Validations before performing the action
      #
      # @note The action can be performed is there are no errors (see #errors).
      #   Only the first error is shown.
      #
      # @return [Boolean]
      def validate
        current_errors = errors
        return true if current_errors.empty?

        Yast2::Popup.show(current_errors.first, headline: :error)
        false
      end

      # List of errors that avoid to create a Bcache
      #
      # @return [Array<String>]
      def errors
        [no_backing_devices_error].compact
      end

      # Error when there is no suitable backing devices for creating a Bcache
      #
      # @return [String, nil] nil if there are devices.
      def no_backing_devices_error
        return nil if suitable_backing_devices.any?

        # TRANSLATORS: Error message.
        _("There are not enough suitable unused devices to create a Bcache.")
      end

      # Creates a bcache device according to the user input
      #
      # @param dialog [Dialogs::Bcache]
      def create_device(dialog)
        backing = dialog.backing_device

        raise "Invalid result #{dialog.inspect}. Backing not found." unless backing

        bcache = backing.create_bcache(Y2Storage::Bcache.find_free_name(device_graph))

        apply_options(bcache, dialog.options)

        attach(bcache, dialog.caching_device) if dialog.caching_device
      end

      # Applies options to the bcache device
      #
      # Right now, the dialog only allows to indicate the cache mode.
      #
      # @param bcache [Y2Storage::Bcache]
      # @param options [Hash<Symbol, Object>]
      def apply_options(bcache, options)
        options.each_pair do |key, value|
          bcache.public_send(:"#{key}=", value)
        end
      end

      # Attaches the selected caching to the bcache
      #
      # @param bcache [Y2Storage::Bcache]
      # @param caching [Y2Storage::BcacheCset, Y2Storage::BlkDevice, nil]
      def attach(bcache, caching)
        return if caching.nil?

        if !caching.is?(:bcache_cset)
          caching.remove_descendants
          caching = caching.create_bcache_cset
        end

        bcache.attach_bcache_cset(caching)
      end

      # Device graph in which the action operates on
      #
      # @return [Y2Storage::Devicegraph]
      def device_graph
        DeviceGraphs.instance.current
      end

      # Suitable devices to be used as backing device
      #
      # @return [Array<Y2Storage::BlkDevice>]
      def suitable_backing_devices
        usable_blk_devices
      end

      # Suitable devices to be used for caching
      #
      # @return [Array<Y2Storage::BcacheCset, Y2Storage::BlkDevice>]
      def suitable_caching_devices
        existing_caches + usable_blk_devices
      end

      # Block devices that can be used as backing or caching device
      #
      # @return [Array<Y2Storage::BlkDevice>]
      def usable_blk_devices
        device_graph.blk_devices.select do |dev|
          dev.component_of.empty? &&
            (dev.filesystem.nil? || dev.filesystem.mount_point.nil?) &&
            (!dev.respond_to?(:partitions) || dev.partitions.empty?) &&
            # do not allow nested bcaches, see doc/bcache.md
            ([dev] + dev.ancestors).none? { |a| a.is?(:bcache, :bcache_cset) }
        end
      end

      # Currently existing caching sets
      #
      # @return [Array<Y2Storage::BcacheCset>]
      def existing_caches
        device_graph.bcache_csets
      end
    end
  end
end
