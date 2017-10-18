module Y2Storage
  module AutoinstProblems
    # Base class for storage-ng autoinstallation problems.
    #
    # Y2Storage::AutoinstProblems offers an API to register and report storage
    # related AutoYaST problems.
    class Problem
      include Yast::I18n

      # Return problem severity
      #
      # * :fatal: abort the installation.
      # * :warn:  display a warning.
      #
      # @return [Symbol] Problem severity (:warn, :fatal)
      # @raise NotImplementedError
      #
      # @see Problem#severity
      def severity
        raise NotImplementedError
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @raise NotImplementedError
      def message
        raise NotImplementedError
      end

      # Determine whether an error is fatal
      #
      # This is just a convenience method.
      #
      # @return [Boolean]
      def fatal?
        severity == :fatal
      end

      # Determine whether an error is just a warning
      #
      # This is just a convenience method.
      #
      # @return [Boolean]
      def warn?
        severity == :warn
      end
    end
  end
end
