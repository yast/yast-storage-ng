require "y2storage/storage_class_wrapper"
require "y2storage/actiongraph"

module Y2Storage
  class Devicegraph
    include StorageClassWrapper
    wrap_class Storage::Devicegraph

    storage_forward :==
    storage_forward :!=
    storage_forward :load
    storage_forward :save
    storage_forward :empty?
    storage_forward :clear
    storage_forward :check
    storage_forward :used_features
    storage_forward :copy
    storage_forward :write_graphviz

    # @return [Devicegraph]
    def dup
      new_graph = ::Storage::Devicegraph.new(to_storage_value.storage)
      copy(new_graph)
      Devicegraph.new(new_graph)
    end
    alias_method :duplicate, :dup

    # Set of actions needed to get this devicegraph
    #
    # By default the starting point is the probed devicegraph
    #
    # @param from [Devicegraph] starting graph to calculate the actions
    #       If nil, the probed devicegraph is used.
    # @return [Actiongraph]
    def actiongraph(from: nil)
      origin = from ? from.to_storage_value : to_storage_value.storage.probed
      graph = ::Storage::Actiongraph.new(to_storage_value.storage, origin, to_storage_value)
      Actiongraph.new(graph)
    end
  end
end
