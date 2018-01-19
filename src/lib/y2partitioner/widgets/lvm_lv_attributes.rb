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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast/i18n"

module Y2Partitioner
  module Widgets
    # Shared helpers to display information about logical volume attributes
    #
    # Requirements:
    #   #lvm_lv [Y2Storage::LvmLv] a logical volume instance.
    module LvmLvAttributes
      extend Yast::I18n

      # Sets textdomain
      def included(_target)
        textdomain "storage"
      end

      # Information about stripes of the logical volume
      #
      # @return [String]
      def device_stripes
        # TRANSLATORS: logical volume stripes information, where %s is replaces by
        # the stripes info
        format(_("Stripes: %s"), stripes_info(lvm_lv))
      end

      # @return [String]
      def stripes_info(lvm_lv)
        if lvm_lv.stripes <= 1
          lvm_lv.stripes.to_i
        else
          format(
            # TRANSLATORS: first %s is the number of LVM stripes and the second one is
            # the stripe size
            _("%s (%s)"),
            lvm_lv.stripes.to_s,
            lvm_lv.stripes_size.to_human_string
          )
        end
      end
    end
  end
end
