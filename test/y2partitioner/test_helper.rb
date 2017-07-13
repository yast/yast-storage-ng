require_relative "../spec_helper"

require "y2storage"
require "y2partitioner/device_graphs"

def devicegraph_stub(name)
  path = File.join(TEST_PATH, "data", "devicegraphs", name)
  storage = Y2Storage::StorageManager.fake_from_yaml(path)

  Y2Partitioner::DeviceGraphs.create_instance(storage.probed, storage.staging)
  storage
end

devicegraph_stub("one-empty-disk.yml")
