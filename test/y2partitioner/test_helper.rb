require_relative "../spec_helper"

require "y2storage"
require "y2partitioner/device_graphs"

def devicegraph_stub(name)
  path = File.join(TEST_PATH, "data", "devicegraphs", name)
  Y2Storage::StorageManager.instance.probe_from_yaml(path)
  storage = Y2Storage::StorageManager.instance

  Y2Partitioner::DeviceGraphs.create_instance(storage.probed, storage.staging)
  storage
end

devicegraph_stub("one-empty-disk.yml")
