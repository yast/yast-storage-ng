require "y2storage/storage_class_wrapper"

module Y2Storage
  class Region
    include StorageClassWrapper
    wrap_class Storage::Region

    storage_forward :==
    storage_forward :!=
    storage_forward :>
    storage_forward :<
    storage_forward :empty?
    storage_forward :start
    storage_forward :length
    storage_forward :end
    storage_forward :start=
    storage_forward :length=
    storage_forward :adjust_start
    storage_forward :adjust_length
    storage_forward :block_size, as: "DiskSize"
    storage_forward :block_size=

    def inspect
      "<Region #{start} - #{self.end}>"
    end

    def show_range
      "#{start} - #{self.end}"
    end

    alias_method :to_s, :inspect

    def self.create(start, length, block_size)
      new(Storage::Region.new(start, length, block_size.to_i))
    end
  end
end
