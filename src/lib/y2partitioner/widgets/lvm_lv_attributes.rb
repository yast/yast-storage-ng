require "yast/i18n"

module Y2Partitioner
  module Widgets
    # shared helpers to display info about Y2Storage::LvmLv attributes
    module LvmLvAttributes
      extend Yast::I18n

      def included(_target)
        textdomain "storage"
      end

      def stripes_info(lvm_lv)
        if lvm_lv.stripes <= 1
          lvm_lv.stripes.to_i
        else
          format(
            # TRANSLATORS: first %s is number of LVM stripes
            # and the second one is for size of stripe
            _("%s (%s)"),
            lvm_lv.stripes.to_s,
            lvm_lv.stripes_size.to_human_string
          )
        end
      end
    end
  end
end
