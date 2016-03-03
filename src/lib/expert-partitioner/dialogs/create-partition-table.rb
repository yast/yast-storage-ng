# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "storage"
require "storage/storage_manager"
require "expert-partitioner/ui-extensions"

Yast.import "UI"
Yast.import "Label"

module ExpertPartitioner
  # UI Dialog for creating a partition table
  class CreatePartitionTableDialog
    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger

    def initialize(disk)
      textdomain "storage"
      @disk = disk
    end

    def run
      return nil unless create_dialog

      begin
        case input = Yast::UI.UserInput
        when :cancel
          nil
        when :ok
          doit
        else
          raise "Unexpected input #{input}"
        end
      ensure
        Yast::UI.CloseDialog
      end
    end

    private

    def create_dialog
      types = @disk.possible_partition_table_types

      tmp = types.to_a.map do |type|
        LeftRadioButton(Id(type), Storage.pt_type_name(type), types[0] == type)
      end

      Yast::UI.OpenDialog(
        VBox(
          Label(_("Select new partition table type for %s.") % @disk.name),
          MarginBox(2, 0.4, RadioButtonGroup(Id(:types), VBox(*tmp))),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Yast::Label.OKButton),
            PushButton(Id(:cancel), Yast::Label.CancelButton)
          )
        )
      )
    end

    def doit
      type = Yast::UI.QueryWidget(Id(:types), :Value)

      if RemoveDescendantsPopup.new(@disk).run
        @disk.create_partition_table(type)
      end
    end
  end
end
