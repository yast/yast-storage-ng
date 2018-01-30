require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/rescan_devices_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for all storage devices in the system
      class System < CWM::Page
        include Yast::I18n

        # Constructor
        #
        # @param [String] hostname of the system, to be displayed
        # @param pager [CWM::TreePager]
        def initialize(hostname, pager)
          textdomain "storage"

          @pager = pager
          @hostname = hostname
        end

        # @macro seeAbstractWidget
        def label
          hostname
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          icon = Icons.small_icon(Icons::ALL)
          @contents = VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading. String followed by the hostname
                Heading(format(_("Available Storage on %s"), hostname))
              )
            ),
            table,
            HBox(RescanDevicesButton.new)
          )
        end

      private

        attr_reader :hostname

        # The table contains all storage devices, including Software RAIDs and LVM Vgs
        #
        # @return [ConfigurableBlkDevicesTable]
        def table
          return @table unless @table.nil?
          @table = ConfigurableBlkDevicesTable.new(devices, @pager)
          @table.remove_columns(:start, :end)
          @table
        end

        # Returns all storage devices
        #
        # @note Software RAIDs and LVM Vgs are included.
        #
        # @return [Array<Y2Storage::Device>]
        def devices
          disk_devices + software_raids + lvm_vgs + nfs_devices
        end

        # @return [Array<Y2Storage::Device>]
        def disk_devices
          device_graph.disk_devices.reduce([]) do |devices, disk|
            devices << disk
            devices.concat(disk.partitions)
          end
        end

        # Returns all LVM volume groups and their logical volumes, including thin pools
        # and thin volumes
        #
        # @see Y2Storage::LvmVg#all_lvm_lvs
        #
        # @return [Array<Y2Storage::LvmVg, Y2Storage::LvmLv>]
        def lvm_vgs
          device_graph.lvm_vgs.reduce([]) do |devices, vg|
            devices << vg
            devices.concat(vg.all_lvm_lvs)
          end
        end

        # @return [Array<Y2Storage::Device>]
        def software_raids
          device_graph.software_raids
        end

        # @return [Array<Y2Storage::Device>]
        def nfs_devices
          device_graph.nfs_mounts
        end

        def device_graph
          DeviceGraphs.instance.current
        end
      end
    end
  end
end
