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

require "yast"
require "y2storage/lvm_vg"
require "y2storage/lvm_lv"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for opening the workflow to add a logical volume to a volume group.
    module LvmValidations
      # TODO
      def validate_add_vg
        return true
      end

      def validate_add_lv(vg)
        if vg.nil?
          Yast::Popup.Error(_("No device selected"))
          return false
        end

        if vg.number_of_free_extents == 0
          Yast::Popup.Error(
            # TRANSLATORS: %s is a volume group name (e.g. "system")
            _("No free space left in the volume group \"%s\".") % vg.vg_name
          )
          return false
        end

        return true
      end
    end
  end
end
