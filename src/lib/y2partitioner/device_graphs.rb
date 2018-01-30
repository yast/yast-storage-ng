module Y2Partitioner
  # A singleton class that helps to work with a copy of the system
  # {Y2Storage::Devicegraph}.
  # FIXME: the spelling is different
  class DeviceGraphs
    # Devicegraph representing the system
    attr_accessor :system
    # Working Devicegraph, to be modified during the partitioner execution
    attr_accessor :current

    def initialize(system: nil, initial: nil)
      @system = system || Y2Storage::StorageManager.instance.probed
      initial ||= Y2Storage::StorageManager.instance.staging
      @current = initial.dup
    end

    # Makes a copy of the `current` devicegraph and runs a block with the copy.
    #
    # If the block fails or raises an exception, then the original devicegraph is restored.
    # Otherwise, the modified copy of the devicegraph becomes the `current` devicegraph.
    #
    # Finally, if an exception is not raised, then the result of the block call is returned.
    #
    # @note It is important to keep the original devicegraph when the transaction is aborted.
    #   In that cases, the interface could not be refreshed, and it continues using the original
    #   devicegraph.
    #
    # @yieldreturn [Boolean]
    # @return What the block returned
    def transaction(&block)
      initial_graph = current
      self.current = initial_graph.dup
      begin
        res = block.call

        self.current = initial_graph if !res
      rescue
        self.current = initial_graph
        raise
      end

      res
    end

    class << self
      def instance
        create_instance(nil, nil) unless @instance
        @instance
      end

      # Creates the singleton instance with customized devicegraphs. To
      # be used during the initialization of the partitioner.
      def create_instance(system, initial)
        @instance = new(system: system, initial: initial)
      end

      # Make sure only .instance and .create_instance can be used to
      # create objects
      private :new, :allocate
    end
  end
end
