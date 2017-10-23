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
require "cwm"
require "y2partitioner/widgets/lvm_validations"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for opening the workflow to add a new volume group
    class AddLvmVgButton < CWM::PushButton
      include LvmValidations

      # Constructor
      def initialize
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        _("Add...")
      end

      # @macro seeAbstractWidget
      # TODO
      def handle
        return nil unless validate_add_vg
        Yast::Popup.Warning("Not yet implemented")
      end
    end
  end
end
