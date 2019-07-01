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

require "cwm/custom_widget"

module Y2Partitioner
  module Widgets
    # Widget that shows bar graph for given LvmVg if UI support it
    class LvmVgBarGraph < CWM::CustomWidget
      def initialize(lvm_vg)
        @lvm_vg = lvm_vg
      end

      # @macro seeCustomWidget
      def contents
        return Empty() unless Yast::UI.HasSpecialWidget(:BarGraph)

        data = @lvm_vg.all_lvm_lvs.map do |lv|
          # lets use size in MiB, disks are now so big, that otherwise it will overflow
          # even for few TB and we passing values to libyui in too low data. Ignoring anything
          # below 1MiB looks OK for me (JReidinger)
          [lv.size.to_i / (2**20), "#{lv.lv_name}\n#{lv.size.to_human_string}"]
        end
        sizes = data.map(&:first)
        labels = data.map { |i| i[1] }
        BarGraph(sizes, labels)
      end
    end
  end
end
