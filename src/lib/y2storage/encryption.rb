# Copyright (c) [2017-2019] SUSE LLC
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

require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"
require "y2storage/crypttab"
require "y2storage/encryption_method"

module Y2Storage
  # An encryption layer on a block device
  #
  # This is a wrapper for Storage::Encryption
  class Encryption < BlkDevice
    wrap_class Storage::Encryption, downcast_to: ["Luks"]

    # @!attribute type
    #   Encryption type. Eg. luks1, luks2, etc.
    #
    #   @return [EncryptionType]
    #
    storage_forward :type, as: "EncryptionType"
    storage_forward :type=

    # @!method blk_device
    #   Block device directly hosting the encryption layer.
    #
    #   @return [BlkDevice] the block device being encrypted
    storage_forward :blk_device, as: "BlkDevice"

    # @!attribute password
    #   @return [String] the encryption password
    storage_forward :password
    storage_forward :password=

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Encryption>] all the encryption devices in the given devicegraph
    storage_class_forward :all, as: "Encryption"

    # @!method in_etc_crypttab?
    #   @return [Boolean] whether the device is included in /etc/crypttab
    storage_forward :in_etc_crypttab?

    # @!attribute key_file
    #   @return [String] the encryption key file
    storage_forward :key_file
    storage_forward :key_file=

    # @!attribute cipher
    #   @return [String] the encryption cipher
    storage_forward :cipher
    storage_forward :cipher=

    # @!attribute key_size
    #   @return [DiskSize] the encryption key size
    storage_forward :key_size, as: "DiskSize"
    storage_forward :key_size=

    # @!attribute crypt_options
    #   @return [Array<String>] options for the encryption
    storage_forward :crypt_options

    # Sets crypt options
    #
    # @param options [Array<String>]
    def crypt_options=(options)
      to_storage_value.crypt_options.clear
      options&.each { |o| to_storage_value.crypt_options << o }
    end

    # The setter is intentionally hidden. See similar comment for Md#in_etc_mdadm
    storage_forward :storage_in_etc_crypttab=, to: :in_etc_crypttab=
    private :storage_in_etc_crypttab=

    # @see BlkDevice#plain_device
    def plain_device
      blk_device
    end

    # @see Device#in_etc?
    # @see #in_etc_crypttab?
    def in_etc?
      in_etc_crypttab?
    end

    # Low level setter to enforce a value for {#dm_table_name} without
    # updating {#auto_dm_name?}
    #
    # @see #dm_table_name=
    alias_method :assign_dm_table_name, :dm_table_name=

    # Overloaded setter for {#dm_table_name} with ensures a consistent value for
    # #{auto_dm_name?} to make sure names set via the setter are not
    # auto-adjusted later.
    #
    # @see #assign_dm_table_name
    #
    # @param name [String]
    def dm_table_name=(name)
      self.auto_dm_name = false
      super
    end

    # Whether {#dm_table_name} was automatically set by YaST.
    #
    # @note This relies on the userdata mechanism, see {#userdata_value}.
    #
    # @return [Boolean] false if the name was explicitly set via the overloaded
    #   setter or in general if the origin is unknown
    def auto_dm_name?
      !!userdata_value(:auto_dm_name)
    end

    # Enforces de value for {#auto_dm_name?}
    #
    # @note This relies on the userdata mechanism, see {#userdata_value}.
    #
    # @param value [Boolean]
    def auto_dm_name=(value)
      save_userdata(:auto_dm_name, value)
    end

    # Whether the encryption device matches with a given crypttab spec
    #
    # The second column of /etc/crypttab contains a path to the underlying
    # device of the encrypted device. For example:
    #
    # /dev/sda2
    # /dev/disk/by-id/scsi-0ATA_Micron_1100_SATA_1652155452D8-part2
    # /dev/disk/by-uuid/7a0c6309-7063-472b-8301-f52b0a92d8e9
    # /dev/disk/by-path/pci-0000:00:17.0-ata-3-part2
    #
    # This method checks whether the underlying device of the encryption is the
    # device indicated in the second column of a crypttab entry.
    #
    # Take into account that libstorage-ng discards during probing all the
    # udev names not considered reliable or stable enough. This method only
    # checks by the udev names recognized by libstorage-ng (not discarded).
    #
    # @param spec [String] content of the second column of an /etc/crypttab entry
    # @return [Boolean]
    def match_crypttab_spec?(spec)
      blk_device.name == spec || blk_device.udev_full_all.include?(spec)
    end

    # Whether the crypttab name is known for this encryption device
    #
    # @return [Boolean]
    def crypttab_name?
      !crypttab_name.nil?
    end

    # Name specified in the crypttab file for this encryption device
    #
    # @note This relies on the userdata mechanism, see {#userdata_value}.
    #
    # @return [String, nil] nil if crypttab name is not known
    def crypttab_name
      userdata_value(:crypttab_name)
    end

    # Saves how this encryption device is known in the crypttab file
    #
    # @note This relies on the userdata mechanism, see {#save_userdata}.
    def crypttab_name=(value)
      save_userdata(:crypttab_name, value)
    end

    # Returns the encryption method used
    #
    # Note that it could be inferred if there is no encryption process available yet
    #
    # @see #encryption_process
    #
    # @return [EncryptionMethod, nil]
    def method
      encryption_process ? encryption_process.method : EncryptionMethod.for_device(self)
    end

    # Saves the given encryption process
    #
    # @note Keeping the state of this object is important, so see {#encryption_process}
    #   and {#save_encryption_process} for some considerations about how it is
    #   persisted into the devicegraph and how the current state is held.
    #
    # @param value [Encryption::Processes]
    def encryption_process=(value)
      save_userdata(:encryption_process, value)
      @encryption_process = value
    end

    # Executes the actions that must be performed right before the devicegraph is
    # committed to the system
    def pre_commit
      return unless encryption_process

      encryption_process.pre_commit(self)
      save_encryption_process
    end

    # Executes the actions that must be performed after the devicegraph has been
    # committed to the system
    def post_commit
      encryption_process&.post_commit(self)
    end

    protected

    def types_for_is
      super << :encryption
    end

    # @see Device#update_etc_attributes
    def assign_etc_attribute(value)
      self.storage_in_etc_crypttab = value
    end

    # Returns the process used to perform the encryption
    #
    # @note The EncryptionProcess object is persisted using the userdata mechanism,
    #   but it's also cached in an instance variable because, otherwise, every call
    #   to #encryption_process would be accessing the object that was stored in the
    #   devicegraph, with its former state. Thus, all the modifications would be lost.
    #   See {#encryption_process=} and {#save_encryption_process}.
    #
    # @return [EncryptionProcess::Base, nil]
    def encryption_process
      @encryption_process ||= userdata_value(:encryption_process)
    end

    # Updates the userdata with an up-to-date version of the encryption process
    #
    # @see #encryption_process
    def save_encryption_process
      self.encryption_process = encryption_process
    end

    class << self
      # Updates the DeviceMapper name for all encryption devices in the device
      # that have a name automatically set by YaST.
      #
      # This is useful to ensure the names of the encryptions are still
      # consistent with the names of the block devices they are associated to,
      # since some devices (like partitions) use to change their names over
      # time.
      #
      # Note that names automatically set by libstorage-ng itself (typically of
      # the form cr-auto-$NUM) are not marked as auto-generated and, thus, are
      # not modified by this method. Modifying such names can confuse
      # libstorage-ng.
      #
      # @param devicegraph [Devicegraph]
      def update_dm_names(devicegraph)
        encryptions = all(devicegraph).select(&:auto_dm_name?).sort_by(&:sid)

        # Reset all auto-generated names...
        encryptions.each do |enc|
          enc.assign_dm_table_name("")
        end

        # ...reassign them according to the current names of the block devices
        encryptions.each do |enc|
          dm_name = dm_name_for(enc.blk_device)
          enc.assign_dm_table_name(dm_name)
        end
      end

      # Auto-generated DeviceMapper name to use for the encrypted version of the
      # given device.
      #
      # @param device [BlkDevice] block device to be encrypted
      # @return [String]
      def dm_name_for(device)
        basename = dm_basename_for(device)
        suffix = ""
        devicegraph = device.devicegraph

        loop do
          candidate = "#{basename}#{suffix}"
          return candidate unless dm_name_in_use?(devicegraph, candidate)

          suffix = next_dm_name_suffix(suffix)
        end
      end

      # Saves encryption names indicated in a crypttab file
      #
      # For each entry in the crypttab file, it finds the corresponding device and updates
      # its crypttab name with the value indicated in its crypttab entry. The device is
      # not modified at all if it is not encrypted.
      #
      # @param devicegraph [Devicegraph]
      # @param crypttab [Crypttab, String] Crypttab object or path to a crypttab file
      def save_crypttab_names(devicegraph, crypttab)
        crypttab = Crypttab.new(crypttab) if crypttab.is_a?(String)

        crypttab.entries.each { |e| save_crypttab_name(devicegraph, e) }
      end

      private

      # Saves the crypttab name according to the value indicated in a crypttab entry
      #
      # Generally, when a crypttab entry points to a luks device, the encryption layer is probed. But in
      # case of plain encrypted devices, the encryption layer could not exist in the probed devicegraph.
      # Note that no headers are written into the device when using plain encryption. And, for this
      # reason, plain encryption devices are only probed for the root filesystem by parsing its crypttab.
      #
      # Due to plain encryption devices could be not probed, this method creates the plain encryption
      # layer to be able to save the encryption name indicated in the crypttab entry.
      #
      # @param devicegraph [Devicegraph]
      # @param entry [SimpleEtcCrypttabEntry]
      def save_crypttab_name(devicegraph, entry)
        device = entry.find_device(devicegraph)

        return unless device

        if device.encrypted?
          device.encryption.crypttab_name = entry.name
        elsif entry.swap?
          # Right now, a plain encryption device is created for swap only. Moreover, random password
          # (urandom) is always considered, even when the crypttab file indicates another key file.
          device.remove_descendants
          device.encrypt(dm_name: entry.name, method: :random_swap)
        end
      end

      # Checks whether a given DeviceMapper table name is already in use by some
      # of the devices in the given devicegraph
      #
      # @param devicegraph [Devicegraph]
      # @param name [String]
      # @return [Boolean]
      def dm_name_in_use?(devicegraph, name)
        devicegraph.blk_devices.any? { |i| i.dm_table_name == name }
      end

      # Initial part of {.dm_name_for}
      #
      # @param device [BlkDevice]
      # @return [String]
      def dm_basename_for(device)
        device_name =
          if device.dm_table_name.empty?
            device.udev_ids.first || device.basename
          else
            device.dm_table_name
          end
        "cr_#{device_name}"
      end

      # @see #dm_name_for
      #
      # @param previous [String] previous value of the suffix
      # @return [String]
      def next_dm_name_suffix(previous)
        previous_num = previous.empty? ? 1 : previous.split("_").last.to_i
        "_#{previous_num + 1}"
      end
    end
  end
end
