# encoding: utf-8

# Copyright (c) [2015-2016] SUSE LLC
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

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"

module ExpertPartitioner
  # UI Dialog for creating a partition
  class CreatePartitionDialog
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
      Yast::UI.OpenDialog(
        VBox(
          Heading(_("Create Partition")),
          RadioButtonGroup(Id(:size), VBox(
                             LeftRadioButton(Id(:max_size), # Opt(:notify),
                                             _("Maximum Size (TODO)")),
                             LeftRadioButtonWithAttachment(Id(:custom_size), # Opt(:notify),
                                                           _("Custom Size"),
                                                           VBox(
                                                             Id(:custom_size_attachment),
                                                             MinWidth(15, InputField(Id(:custom_size_input), Opt(:shrinkable), _("Size"), "50 MiB")),
                                                           )
                                                          )
                           )
                          ),
          ButtonBox(
            PushButton(Id(:cancel), Yast::Label.CancelButton),
            PushButton(Id(:ok), Yast::Label.OKButton)
          )
        )
      )
    end

    def doit

      partition_table = @disk.partition_table
      partition_slots = partition_table.unused_partition_slots.to_a

      case Yast::UI.QueryWidget(Id(:size), :Value)

      when :max_size

        partition_slot = partition_slots[0]

        partition_slot.region = partition_table.align(partition_slot.region,
                                                      Storage::AlignPolicy_KEEP_END)

      when :custom_size

        size = Yast::UI.QueryWidget(Id(:custom_size_input), :Value)
        size = Storage.humanstring_to_byte(size, false)

        partition_slots.delete_if do |partition_slot|
          !partition_slot.primary_slot || !partition_slot.primary_possible ||
            size > partition_slot.region.to_bytes(partition_slot.region.length)
        end

        if partition_slots.empty?
          Yast::Popup::Error("No suitable partition slot found.")
          return
        end

        partition_slot = partition_slots[0]
        partition_slot.region.length = partition_slot.region.to_blocks(size)

      end

      partition_table.create_partition(
        partition_slot.name,
        partition_slot.region,
        Storage::PartitionType_PRIMARY
      )
    end
  end
end
