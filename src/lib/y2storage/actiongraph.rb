require "y2storage/storage_class_wrapper"

module Y2Storage
  class Actiongraph
    include StorageClassWrapper
    wrap_class Storage::Actiongraph

    storage_forward :empty?
    storage_forward :print_graph
    storage_forward :write_graphviz
    storage_forward :commit_actions
    storage_forward :commit_actions_as_strings
  end
end
