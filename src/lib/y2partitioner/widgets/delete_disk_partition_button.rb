require "yast"
require "cwm"

Yast.import "Popup"
Yast.import "HTML"

module Y2Partitioner
  module Widgets
    # Delete a partition
    class DeleteDiskPartitionButton < CWM::PushButton
      # Constructor
      # @param device [Y2Storage::BlkDevice]
      # @param table [Y2Partitioner::Widgets::BlkDevicesTable]
      # @param device_graph [Y2Storage::Devicegraph]
      def initialize(device: nil, table: nil, device_graph: nil)
        textdomain "storage"

        unless device || (table && device_graph)
          raise ArgumentError,
            "At least device or combination of table and device_graph have to be set"
        end
        @device = device
        @table = table
        @device_graph = device_graph
      end

      def label
        _("Delete...")
      end

      def handle
        device = @device || @table.selected_device

        if device.nil?
          Yast::Popup.Error(_("No device selected"))
          return nil
        end

        return nil unless confirm(device)

        delete_devices(device)
        :redraw
      end

    private

      def delete_devices(device)
        if device.is?(:disk)
          log.info "deleting partitions for #{device}"
          device.partition_table.delete_all_partitions
        else
          log.info "deleting partition #{device}"
          disk = device.disk
          disk.partition_table.delete_partition(device)
        end

        devicegraph = DeviceGraphs.instance.current
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(devicegraph)
      end

      def confirm(device)
        names = children_names(device)

        if names.empty?
          Yast::Popup.YesNo(
            # TRANSLATORS %s is device to be deleted
            format(_("Really delete %s?"), device.name)
          )
        else
          confirm_recursive_delete(
            names,
            _("Confirm Deleting of All Partitions"),
            # TRANSLATORS: type stands for type of device and name is its identifier
            format(_("The %{type} \"%{name}\" contains at least one another device.\n" \
              "If you proceed, the following devices will be deleted:"),
              name: device.name,
              type: device.is?(:disk) ? _("disk") : _("partition")),
            format(_("Really delete all devices on \"%s\"?"), device.name)
          )
        end
      end

      def children_names(device)
        device.descendants.map do |dev|
          dev.name if dev.respond_to?(:name)
        end.compact
      end

      # @param rich_text [String]
      # @return [Boolean]
      def fancy_question(headline, label_before, rich_text, label_after, button_term)
        display_info = Yast::UI.GetDisplayInfo || {}
        has_image_support = display_info["HasImageSupport"]

        layout = VBox(
          VSpacing(0.4),
          HBox(
            has_image_support ? Top(Image(Yast::Icon.IconPath("question"))) : Empty(),
            HSpacing(1),
            VBox(
              Left(Heading(headline)),
              VSpacing(0.2),
              Left(Label(label_before)),
              VSpacing(0.2),
              Left(RichText(rich_text)),
              VSpacing(0.2),
              Left(Label(label_after)),
              button_term
            )
          )
        )

        Yast::UI.OpenDialog(layout)
        ret = Yast::UI.UserInput
        Yast::UI.CloseDialog

        ret == :yes
      end

      # TODO: copy and pasted code from old storage, feel free to improve
      def confirm_recursive_delete(devices, headline, label_before, label_after)
        button_box = ButtonBox(
          PushButton(Id(:yes), Opt(:okButton), Yast::Label.DeleteButton),
          PushButton(
            Id(:no_button),
            Opt(:default, :cancelButton),
            Yast::Label.CancelButton
          )
        )

        fancy_question(headline,
          label_before,
          Yast::HTML.List(devices.sort),
          label_after,
          button_box)
      end
    end
  end
end
