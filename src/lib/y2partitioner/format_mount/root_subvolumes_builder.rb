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
require "y2storage"
require "y2storage/subvol_specification"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module FormatMount
    # Class to manage root subvolumes in expert partitioner
    class RootSubvolumesBuilder
      def initialize
        reload
      end

      def reload
        if filesystem.nil?
          @sid = nil
          @subvolumes_spec = []
        elsif @sid != filesystem.sid
          @sid = filesystem.sid
          create_subvolumes_spec
        end
      end

      def create_subvolumes
        return false if sid.nil?

        create_subvolumes_spec_for_current_product

        default_path = Y2Storage::Filesystems::Btrfs.default_btrfs_subvolume_path
        filesystem.ensure_default_btrfs_subvolume(path: default_path)

        subvolumes_spec.each do |spec|
          create_subvolume_from_spec(spec)
        end

        true
      end

      def remove_subvolumes
        return false if sid.nil?

        remove_subvolumes_spec

        fs = filesystem
        subvolumes.each do |subvolume|
          fs.delete_btrfs_subvolume(devicegraph, subvolume.path)
        end

        true
      end

      def remove_shadowed_subvolumes
        return false if sid.nil?

        fs = filesystem
        subvolumes.each do |subvolume|
          fs.delete_btrfs_subvolume(devicegraph, subvolume.path) if subvolume.shadowed?(devicegraph)
        end

        true
      end

      def add_subvolume(path, nocow)
        return false if sid.nil?

        spec = add_subvolume_spec(path, nocow)
        create_subvolume_from_spec(spec)

        true
      end

      def remove_subvolume(path)
        return false if sid.nil?

        remove_subvolume_spec(path)
        filesystem.delete_btrfs_subvolume(devicegraph, path)

        true
      end

      def add_subvolumes_shadowed_by(mount_point)
        return false if sid.nil?

        subvolumes_spec_shadowed_by(mount_point).each do |spec|
          create_subvolume_from_spec(spec)
        end

        true
      end

      def remove_subvolumes_shadowed_by(mount_point)
        return false if sid.nil?

        fs = filesystem
        subvolumes_shadowed_by(mount_point).each do |subvolume|
          fs.delete_btrfs_subvolume(devicegraph, subvolume.path)
        end

        true
      end

    private

      attr_reader :subvolumes_spec

      attr_reader :sid

      def create_subvolumes_spec
        if new_filesystem?
          create_subvolumes_spec_for_current_product
        else
          create_subvolumes_spec_from_filesystem
        end
      end

      def remove_subvolumes_spec
        @subvolumes_spec = []
      end

      def create_subvolumes_spec_for_current_product
        @subvolumes_spec = Y2Storage::SubvolSpecification.for_current_product
        @subvolumes_spec.each do |spec|
          spec.path = filesystem.btrfs_subvolume_path(spec.path)
        end
      end

      def create_subvolumes_spec_from_filesystem
        @subvolumes_spec = []

        subvolumes.each do |subvolume|
          add_subvolume_spec(subvolume.path, subvolume.nocow?)
        end
      end

      def add_subvolume_spec(path, nocow)
        spec = Y2Storage::SubvolSpecification.new(path, copy_on_write: !nocow)
        @subvolumes_spec << spec
        spec
      end

      def remove_subvolume_spec(path)
        @subvolumes_spec.reject! { |s| s.path == path }
      end

      def subvolumes_shadowed_by(mount_point)
        subvolumes.select { |s| s.shadowed_by?(devicegraph, mount_point) }
      end

      def subvolumes_spec_shadowed_by(mount_point)
        fs = filesystem
        subvolumes_spec.select do |spec|
          subvolume_mount_point = filesystem.btrfs_subvolume_mount_point(spec.path)
          Y2Storage::Mountable.shadowing?(mount_point, subvolume_mount_point)
        end
      end

      def create_subvolume_from_spec(spec)
        filesystem.create_btrfs_subvolume(spec.path, !spec.copy_on_write)
      end

      def devicegraph
        DeviceGraphs.instance.current
      end

      def filesystem
        filesystems = Y2Storage::Filesystems::BlkFilesystem.all(devicegraph)
        filesystems.detect { |f| f.supports_btrfs_subvolumes? && f.root? }
      end

      def new_filesystem?
        initial_devicegraph = DeviceGraphs.instance.system
        !filesystem.exists_in_devicegraph?(initial_devicegraph)
      end

      def subvolumes
        filesystem.btrfs_subvolumes.reject { |s| s.top_level? || s.default_btrfs_subvolume? }
      end

      class << self        
        def create_subvolumes
          ensure_instance
          @instance.remove_subvolumes
          @instance.create_subvolumes
          @instance.remove_shadowed_subvolumes
        end

        def remove_subvolumes
          ensure_instance
          @instance.remove_subvolumes
        end

        def add_subvolume(path, nocow)
          ensure_instance
          @instance.add_subvolume(path, nocow)
        end

        def remove_subvolume(path)
          ensure_instance
          @instance.remove_subvolume(path)
        end

        def add_subvolumes_shadowed_by(mount_point)
          ensure_instance
          @instance.add_subvolumes_shadowed_by(mount_point)
        end

        def remove_subvolumes_shadowed_by(mount_point)
          ensure_instance
          @instance.remove_subvolumes_shadowed_by(mount_point)
        end

        # Make sure objects cannot be manually created
        private :new, :allocate

      private

        def ensure_instance
          if @instance.nil?
            @instance = new
          else
            @instance.reload
          end
        end
      end  
    end
  end
end
