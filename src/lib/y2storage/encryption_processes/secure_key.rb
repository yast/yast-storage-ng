# Copyright (c) [2019] SUSE LLC
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

require "yast2/execute"

module Y2Storage
  module EncryptionProcesses
    # Class representing the secure AES keys managed by the Crypto Express CCA
    # coprocessors found in the system.
    #
    # For more information, see
    # https://www.ibm.com/support/knowledgecenter/linuxonibm/com.ibm.linux.z.lxdc/lxdc_zkey_reference.html
    class SecureKey
      attr_reader :name

      def initialize(name)
        @name = name
        @volume_entries = []
      end

      def read_zkey_volumes(string)
        # TODO: likely this method could be better implemented with
        # StringScanner

        vol_pattern = "\s+\/[^\s]*\s*\n"
        match_data = /\s* Volumes\s+:((#{vol_pattern})+)/.match(string)
        return [] unless match_data

        volumes_str = match_data[1]
        volumes = volumes_str.split("\n").map(&:strip)

        self.volume_entries = volumes.map { |str| Volume.new_from_str(str) }
      end

      def dm_name(blk_device)
        entry = volume_entries.find do |vol|
          self.class.blk_device_names(blk_device).include?(vol.plain_name)
        end
        entry ? entry.dm_name : nil
      end

      def add_device(device)
        @volume_entries << Volume.new_from_encryption(device)
      end

      def generate
        args = [
          "--name", name,
          "--xts", 
          "--keybits", "256",
          "--volume-type", "LUKS2",
          "--sector-size", "4096"
        ]
        if volume_entries.any?
          args += ["--volumes", volume_entries.map(&:to_s).join(",")]
        end

        Yast::Execute.locally("zkey", "generate", *args)
      end

      class Volume
        attr_reader :plain_name
        attr_reader :dm_name

        def initialize(plain_name, dm_name)
          @plain_name = plain_name
          @dm_name = dm_name
        end

        def self.new_from_str(string)
          plain, dm = string.split(":")
          new(plain, dm)
        end

        def self.new_from_encryption(device)
          # TODO. Choose good names
          new(device.blk_device.name, device.dm_table_name)
        end

        def to_s
          dm_name ? "#{plain_name}:#{dm_name}" : plain_name
        end
      end

      private

      attr_accessor :volume_entries

      class << self
        # Whether it's possible to use secure AES keys in this system
        #
        # @return [Boolean]
        def available?
          device_list = Yast::Execute.locally!("/sbin/lszcrypt", "--verbose", stdout: :capture)
          device_list&.match?(/\sonline\s/) || false
        rescue Exception
          false
        end

        # @return [SecureKey]
        def generate(name, volumes: [])
          name = exclusive_name(name)
          key = new(name)
          volumes.each { |vol| key.add_device(vol) }
          key.generate
          key
        end

        # Finds an existing secure key that references the given block device in
        # one of its "volumes" entries
        #
        # @return [SecureKey, nil] nil if no key is found for the device
        def for_plain_device(device)
          names_str = blk_device_names(device).join(",")

          output = Yast::Execute.locally("zkey", "list", "--volumes", names_str, stdout: :capture)
          parse_zkey_list(output).first
        end

        def blk_device_names(device)
          [device.name] + device.udev_full_all
        end

        private

        def all
          output = Yast::Execute.locally("zkey", "list", stdout: :capture)
          parse_zkey_list(output)
        end

        def parse_zkey_list(output)
          return [] if output.empty?

          entries = output.split("\n\n")
          entries.map { |entry| new_from_zkey(entry) }
        end

        def new_from_zkey(string)
          lines = string.lines
          name = lines.first.strip.split(/\s/).last
          key = new(name)
          key.read_zkey_volumes(string)
          key
        end

        def exclusive_name(original_name)
          existing_names = all.map(&:name)
          return original_name unless existing_names.include?(original_name)

          suffix = 0
          name = "#{original_name}#{suffix}"
          while existing_names.include?(name)
            suffix += 1
            name = "#{original_name}#{suffix}"
          end
          name
        end
      end
    end
  end
end
