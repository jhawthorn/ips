# frozen_string_literal: true

module IPS
  class Job
    class Entry
      attr_reader :label

      def initialize(label, action)
        @label = label
        @action = action

        if action.arity > 0
          define_call_times_manual_loop
        else
          define_call_times_block
        end
      end

      private

      def define_call_times_block
        act = @action
        define_singleton_method(:call_times) do |times|
          i = 0
          while i < times
            act.call
            i += 1
          end
        end
      end

      def define_call_times_manual_loop
        act = @action
        define_singleton_method(:call_times) do |times|
          act.call(times)
        end
      end
    end
  end
end
