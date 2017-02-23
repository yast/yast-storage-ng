require "storage"
require "byebug"

module Y2Storage
  module StorageClassWrapper
    def self.included(base)
      base.extend(ClassMethods)
    end

    def to_storage_value
      @storage_object
    end

    def initialize(object)
      cast_method = :"to_#{self.class.storage_class_underscored_name}"
      if Storage.respond_to?(cast_method)
        @storage_object = Storage.send(cast_method, object)
      else
        @storage_object = object
      end
    end

    module ClassMethods
      def storage_forward(method, as: nil)
        define_method(method) do |*args|
          res = StorageClassWrapper.forward(to_storage_value, method, as, *args)
          res
        end
      end

      def storage_class_forward(method, as: nil)
        define_singleton_method(method) do |*args|
          StorageClassWrapper.forward(storage_class, method, as, *args)
        end
      end

      def storage_class
        @storage_class
      end

      def storage_class_name
        @storage_class_name ||= storage_class.name.split("::").last
      end

      def storage_class_underscored_name
        @storage_class_underscored_name ||= StorageClassWrapper.underscore(storage_class_name)
      end

      def wrap_class(storage_class, downcast_to: nil)
        @storage_class = storage_class
        @downcast_class_names = Array(downcast_to).compact
      end

      def downcasted_new(object)
        @downcast_class_names.each do |class_name|
          underscored = StorageClassWrapper.underscore(class_name.split("::").last)
          check_method = :"#{underscored}?"
          cast_method = :"to_#{underscored}"
          next unless Storage.send(check_method, object)

          klass = StorageClassWrapper.class_for(class_name)
          return klass.downcasted_new(Storage.send(cast_method, object))
        end
        new(object)
      end
    end
      
    def self.forward(storage_object, method, wrapper_class_name, *args)
      processed_args = processed_storage_args(*args)
      result = storage_object.send(method, *processed_args)
      processed_storage_result(result, class_for(wrapper_class_name))
    rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
      nil
    end

    def self.class_for(class_name)
      class_name ? Y2Storage.const_get(class_name) : nil
    end

    def self.processed_storage_args(*args)
      args.map { |arg| arg.respond_to?(:to_storage_value) ? arg.to_storage_value : arg }
    end
      
    def self.processed_storage_result(result, wrapper_class)
      if result.class.name.start_with?("Storage::Vector")
        result = result.to_a
      end
      
      if wrapper_class
        if result.is_a?(Array)
          result = result.map {|o| object_for(wrapper_class, o) }
        else
          result = object_for(wrapper_class, result)
        end
      end
      result
    end

    def self.underscore(camel_case_name)
      camel_case_name.gsub(/(.)([A-Z])/,'\1_\2').downcase
    end

    def self.object_for(wrapper_class, storage_object)
      if wrapper_class.respond_to?(:downcasted_new)
        wrapper_class.downcasted_new(storage_object)
      else
        wrapper_class.new(storage_object)
      end
    end
  end
end
