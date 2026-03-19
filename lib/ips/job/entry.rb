# frozen_string_literal: true

module IPS
  class Job
    class Entry
      attr_reader :label

      def initialize(label, action)
        @label = label

        if action.kind_of?(String)
          compile_string(action)
        elsif action.arity > 0
          define_call_times_manual_loop(action)
        else
          define_call_times_block(action)
        end
      end

      private

      def compile_string(str)
        m = (class << self; self; end)
        m.class_eval <<-CODE
          def call_times(__total)
            __i = 0
            while __i < __total
              #{str}
              __i += 1
            end
          end
        CODE
      end

      def define_call_times_block(act)
        define_singleton_method(:call_times) do |times|
          i = 0
          while i < times
            act.call
            i += 1
          end
        end
      end

      def define_call_times_manual_loop(act)
        define_singleton_method(:call_times) do |times|
          act.call(times)
        end
      end
    end
  end
end
