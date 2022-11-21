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

require "y2partitioner/widgets/description_section/base"
require "y2partitioner/widgets/blk_device_attributes"
require "y2storage/pbkd_function"

module Y2Partitioner
  module Widgets
    module DescriptionSection
      # Description section with specific data about a block device
      class BlkDevice < Base
        include BlkDeviceAttributes

        # Constructor
        #
        # @param device [Yy2Storage::BlkDevice]
        def initialize(device)
          textdomain "storage"

          super
        end

        private

        # Required by mixin {BlkDeviceAttributes}
        alias_method :blk_device, :device

        # @see DescriptionSection::Base#title
        def title
          # TRANSLATORS: title for section about block device details
          _("Device:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          [:device, :size, :encrypted] + encryption_entries + udev_entries
        end

        # Entry data about the device name
        #
        # @see BlkDeviceAttributes
        #
        # @return [String]
        def device_value
          device_name
        end

        # Entry data about the device size
        #
        # @see BlkDeviceAttributes
        #
        # @return [String]
        def size_value
          device_size
        end

        # Entry data about the encryption
        #
        # @see BlkDeviceAttributes
        #
        # @return [String]
        def encrypted_value
          device_encrypted
        end

        # Entry data about the udev by_path values
        #
        # @see BlkDeviceAttributes
        #
        # @return [String]
        def udev_path_value
          device_udev_by_path.join(Yast::HTML.Newline)
        end

        # Entry data about the udev by_id values
        #
        # @see BlkDeviceAttributes
        #
        # @return [String]
        def udev_id_value
          device_udev_by_id.join(Yast::HTML.Newline)
        end

        # Entry data about the LUKS2 PBKDF
        #
        # @return [String]
        def pbkdf_value
          pbkdf = blk_device.encryption.pbkdf
          # TRANSLATORS: %s becomes the name of the PBKDF function used by a LUKS2 device (eg. Argon2i)
          format(_("Key Derivation Function (PBKDF): %s"), pbkdf.name)
        end

        # Entry data about the LUKS label
        #
        # @return [String]
        def encryption_label_value
          # TRANSLATORS: %s is replaced by the value of the label of the LUKS2 device
          format(_("LUKS Label: %s"), blk_device.encryption.label)
        end

        # @see #entries
        def encryption_entries
          return [] unless blk_device.encryption&.type&.is?(:luks2)

          [:pbkdf, :encryption_label]
        end

        # @see #entries
        def udev_entries
          [:udev_path, :udev_id]
        end
      end
    end
  end
end
