require "yast"
require "cwm"
require "y2partitioner/format_mount/root_subvolumes_builder"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Delete a partition
    class DeleteDiskPartitionButton < CWM::PushButton
      # @param device
      # @param table [Y2Partitioner::Widgets::BlkDevicesTable]
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
        device = @device || id_to_device(@table.value)

        if device.nil?
          Yast::Popup.Error(_("No device selected"))
          return nil
        end

        return nil unless confirm(device)

        if device.is?(:disk)
          log.info "deleting partitions for #{device}"
          device.partition_table.partitions.each { |p| delete_partition(p) }
        else
          log.info "deleting partition #{device}"
          delete_partition(device)
        end

        :redraw
      end

    private

      def delete_partition(device)
        add_subvolumes_shadowed_by(device.filesystem)
        device.partition_table.delete_partition(device)
      end

      def add_subvolumes_shadowed_by(filesystem)
        return if filesystem.nil? || filesystem.mount_point.nil? || filesystem.root?
        FormatMount::RootSubvolumesBuilder.add_subvolumes_shadowed_by(filesystem.mount_point)
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

      def id_to_device(id)
        return nil if id.nil?

        if id.start_with?("table:partition")
          partition_name = id[/table:partition:(.*)/, 1]
          Y2Storage::Partition.find_by_name(@device_graph, partition_name)
        elsif id.start_with?("table:disk")
          disk_name = id[/table:disk:(.*)/, 1]
          Y2Storage::Disk.find_by_name(@device_graph, disk_name)
        else
          raise "Unknown id in table '#{id}'"
        end
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
