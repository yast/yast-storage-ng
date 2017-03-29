require "y2storage/storage_class_wrapper"

module Y2Storage
  # Container of the actions that must be performed in one devicegraph to make
  # it equivalent to another one.
  #
  # This is a wrapper for Storage::Devicegraph
  class Actiongraph
    include StorageClassWrapper
    wrap_class Storage::Actiongraph

    # @!method empty?
    #   Checks whether the actiongraph is empty (no actions)
    storage_forward :empty?

    # @!method print_graph
    #   Prints a textual representation of the graph through stdout
    storage_forward :print_graph

    # @!write_graphviz(filename, graphviz_flags)
    #   Writes the devicegraph to a file in Graphviz format
    storage_forward :write_graphviz

    # @!commit_actions_as_strings
    #   @return [Array<String>] Action descriptions sorted according to
    #     dependencies among actions
    storage_forward :commit_actions_as_strings
  end
end
