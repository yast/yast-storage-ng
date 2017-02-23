require "y2storage/storage_enum_wrapper"

module Y2Storage
  module Filesystems
    class MountByType
      include StorageEnumWrapper

      wrap_enum "Storage::MountByType", names: [:device, :uuid, :label, :id, :path]
    end
  end
end
