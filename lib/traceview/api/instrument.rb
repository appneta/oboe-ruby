module TraceView
  module API
    module Instrument

      ##
      # instrument_method
      #
      # Public: Instrument a method on a class or module.  That method can be of any (accessible)
      # type (instance, singleton, private, protected etc.).
      #
      # This is centralized instrumentation.  Both TraceView::API.profile_method and
      # TraceView::API.trace_method point here since the only difference is really
      # the event types that are generated (profile or layer).
      #
      # klass  - the class or module that has the method to instrument
      # method - the method to instrument.  Can be singleton, instance, private etc...
      # opts   - a hash specifying the one or more of the following options:
      #   * :profile    - if true, instrument this method as a profile; otherwise a layer (default: false)
      #   * :arguments  - report the arguments passed to <tt>method</tt> (default: false)
      #   * :result     - report the return value of <tt>method</tt> (default: false)
      #   * :backtrace  - report the return value of <tt>method</tt> (default: false)
      #   * :name       - alternate name for the profile or layer reported in the dashboard (default: method name)
      #   * :extra_kvs  - a hash containing any additional KVs you would like reported
      #
      # Example
      #
      #   opts = {}
      #   opts[:backtrace] = true
      #   opts[:arguments] = false
      #   opts[:name] = :array_sort
      #
      #   TraceView::API.profile_method(Array, :sort, opts)
      #
      def instrument_method(klass, method, opts = {}, extra_kvs = {})

        return false unless valid_instrumentation(klass, method, opts, extra_kvs)

        method = method.to_sym if method.is_a?(String)

        instance_method = klass.instance_methods.include?(method) || klass.private_instance_methods.include?(method)
        class_method = klass.singleton_methods.include?(method)

        # Make sure the requested klass::method exists
        if !instance_method && !class_method
          TraceView.logger.warn "[traceview/error] profile_method: Can't instrument #{klass}.#{method} as it doesn't seem to exist."
          TraceView.logger.warn "[traceview/error] #{__FILE__}:#{__LINE__}"
          return false
        end

        # Strip '!' or '?' from method if present
        safe_method_name = method.to_s.chop if method.to_s =~ /\?$|\!$/
        safe_method_name ||= method

        without_traceview = "#{safe_method_name}_without_traceview"
        with_traceview    = "#{safe_method_name}_with_traceview"

        # Check if already profiled
        if klass.instance_methods.include?(with_traceview.to_sym) ||
           klass.singleton_methods.include?(with_traceview.to_sym)
          TraceView.logger.warn "[traceview/error] profile_method: #{klass}::#{method} already profiled."
          TraceView.logger.warn "[traceview/error] profile_method: #{__FILE__}:#{__LINE__}"
          return false
        end

        source_location = []
        if instance_method
          ::TraceView::Util.send_include(klass, ::TraceView::MethodProfiling)
          source_location = klass.instance_method(method).source_location
        elsif class_method
          ::TraceView::Util.send_extend(klass, ::TraceView::MethodProfiling)
          source_location = klass.method(method).source_location
        end

        report_kvs = collect_instrument_kvs(klass, method, opts, extra_kvs, source_location)
        report_kvs[:MethodName] = safe_method_name
        opts[:name] ||= safe_method_name

        if instance_method
          klass.class_eval do
            define_method(with_traceview) do |*args, &block|
              instrument_wrapper(without_traceview, report_kvs, opts, *args, &block)
            end

            alias_method without_traceview, method.to_s
            alias_method method.to_s, with_traceview
          end
        elsif class_method
          klass.define_singleton_method(with_traceview) do |*args, &block|
            instrument_wrapper(without_traceview, report_kvs, opts, *args, &block)
          end

          klass.singleton_class.class_eval do
            alias_method without_traceview, method.to_s
            alias_method method.to_s, with_traceview
          end
        end
        true
      end

      private
        ##
        # valid_instrumentation
        #
        #
        def valid_instrumentation(klass, method, opts, extra_kvs)
          # If we're on an unsupported platform (ahem Mac), just act
          # like we did something to nicely play the no-op part.
          return true unless TraceView.loaded

          if RUBY_VERSION < '1.9.3'
            TraceView.logger.warn '[traceview/error] profile_method: Use the legacy method profiling for Ruby versions before 1.9.3'
            return false

          elsif !klass.is_a?(Module)
            TraceView.logger.warn "[traceview/error] profile_method: Not sure what to do with #{klass}.  Send a class or module."
            return false

          elsif !method.is_a?(Symbol)
            unless method.is_a?(String)
              TraceView.logger.warn "[traceview/error] profile_method: Not sure what to do with #{method}.  Send a string or symbol for method."
              return false
            end
          end
          true
        end

        ##
        # Private: Helper method to aggregate KVs to report
        #
        # klass  - the class or module that has the method to profile
        # method - the method to profile.  Can be singleton, instance, private etc...
        # opts   - a hash specifying the one or more of the following options:
        #   * :arguments  - report the arguments passed to <tt>method</tt> on each profile (default: false)
        #   * :result     - report the return value of <tt>method</tt> on each profile (default: false)
        #   * :backtrace  - report the return value of <tt>method</tt> on each profile (default: false)
        #   * :name       - alternate name for the profile reported in the dashboard (default: method name)
        # extra_kvs - a hash containing any additional KVs you would like reported with the profile
        # source_location - array returned from klass.method(:name).source_location
        #
        def collect_instrument_kvs(klass, method, opts, extra_kvs, source_location)
          report_kvs = {}
          report_kvs[:Language] ||= :ruby
          report_kvs[:ProfileName] ||= opts[:name] ? opts[:name] : method

          if klass.is_a?(Class)
            report_kvs[:Class] = klass.to_s
          else
            report_kvs[:Module] = klass.to_s
          end

          # If this is a Rails Controller, report the KVs
          if defined?(::AbstractController::Base) && klass.ancestors.include?(::AbstractController::Base)
            report_kvs[:Controller] = klass.to_s
            report_kvs[:Action] = method.to_s
          end

          # We won't have access to this info for native methods (those not defined in Ruby).
          if source_location.is_a?(Array) && source_location.length == 2
            report_kvs[:File] = source_location[0]
            report_kvs[:LineNumber] = source_location[1]
          end

          # Merge in any extra_kvs requested
          report_kvs.merge!(extra_kvs)
        end
      # end private
    end
  end
end
