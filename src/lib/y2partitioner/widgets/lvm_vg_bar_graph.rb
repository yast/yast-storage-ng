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

        data = @lvm_vg.lvm_lvs.map do |lv|
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
