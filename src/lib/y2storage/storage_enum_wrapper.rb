require "storage"

module Y2Storage
  module StorageEnumWrapper
    def self.included(base)
      base.extend(ClassMethods)
    end

    def to_storage_value
      @storage_value
    end

    def initialize(value)
      if value.is_a?(::Fixnum)
        @storage_value = value
      else
        @storage_value = Object.const_get("#{self.class.storage_enum}_#{value.to_s.upcase}")
      end
    end

    def to_i
      to_storage_value
    end

    def to_sym
      self.class.value_to_sym(to_storage_value)
    end

    def to_s
      to_sym.to_s
    end

    def is?(name)
      self.to_sym == name.to_sym
    end

    def ==(other)
      other.class == self.class && other.to_storage_value == to_storage_value
    end

    alias_method :eql?, :==

    module ClassMethods
      def storage_enum
        @storage_enum
      end

      def value_to_sym(value)
        @storage_symbols[value]
      end

      def wrap_enum(storage_enum, names: [])
        @storage_enum = storage_enum

        mapping = names.map { |s| [Object.const_get("#{storage_enum}_#{s.upcase}"), s.to_sym] }
        @storage_symbols = Hash[*mapping.flatten]
      end

      def all
        @storage_symbols.keys.sort.map { |storage_value| self.new(storage_value) }
      end

      def find(name_or_value)
        new(name_or_value)
      end
    end
  end
end
