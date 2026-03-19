# frozen_string_literal: true

module IPS
  class Job
    class Entry
      attr_reader :label, :source

      def initialize(label, action)
        @label = label
        @source = nil

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
        @source = <<-CODE.gsub(/^          /, "")
          def call_times(__total)
            __i = 0
            while __i < __total
              #{str}
              __i += 1
            end
          end
        CODE
        m = (class << self; self; end)
        m.class_eval(@source)
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
