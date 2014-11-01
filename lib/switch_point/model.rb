require 'switch_point/proxy_repository'

module SwitchPoint
  module Model
    def self.included(model)
      model.singleton_class.class_eval do
        include ClassMethods
        alias_method_chain :connection, :switch_point
      end
    end

    module ClassMethods
      def connection_with_switch_point
        if switch_point_proxy
          switch_point_proxy.connection
        else
          connection_without_switch_point
        end
      end

      def with_readonly(&block)
        if switch_point_proxy
          switch_point_proxy.with_readonly(&block)
        else
          block.call
        end
      end

      def with_writable(&block)
        if switch_point_proxy
          switch_point_proxy.with_writable(&block)
        else
          block.call
        end
      end

      def use_switch_point(name)
        assert_existing_switch_point!(name)
        @switch_point_name = name
      end

      def switch_point_proxy
        if @switch_point_name
          ProxyRepository.checkout(@switch_point_name)
        else
          nil
        end
      end

      def transaction_with(*models, &block)
        unless can_transaction_with?(*models)
          raise RuntimeError.new("switch_point's model names must be consistent")
        end

        with_writable do
          self.transaction(&block)
        end
      end

      private

      def assert_existing_switch_point!(name)
        SwitchPoint.config.fetch(name)
      end

      def can_transaction_with?(*models)
        writable_switch_points = [self, *models].map do |model|
          if model.instance_variable_defined?(:@switch_point_name)
            SwitchPoint.config.model_name(
              model.instance_variable_get(:@switch_point_name),
              :writable
            )
          else
            nil
          end
        end

        writable_switch_points.uniq.size == 1
      end
    end
  end
end
