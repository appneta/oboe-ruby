# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'digest/sha1'

module TraceView
  module Util
    ##
    # This module is used solely for RUM ID calculation
    #
    module Base64URL
      module_function

      def encode(bin)
        c = [bin].pack('m0').gsub(/\=+\Z/, '').tr('+/', '-_').rstrip
        m = c.size % 4
        c += '=' * (4 - m) if m != 0
        c
      end

      def decode(bin)
        m = bin.size % 4
        bin += '=' * (4 - m) if m != 0
        bin.tr('-_', '+/').unpack('m0').first
      end
    end
  end

  ##
  # This module houses all of the loading functionality for the traceview gem.
  #
  # Note that this does not necessarily _have_ to include initialization routines
  # (although it can).
  #
  # Actual initialization is often separated out as it can be dependent on on the state
  # of the stack boot process.  e.g. code requiring that initializers, frameworks or
  # instrumented libraries are already loaded...
  #
  module Loading
    ##
    # Load the TraceView access key (either from system configuration file
    # or environment variable) and calculate internal RUM ID
    #
    def self.load_access_key
      if ENV.key?('TRACEVIEW_CUUID')
        # Preferably get access key from environment (e.g. Heroku)
        TraceView::Config[:access_key] = ENV['TRACEVIEW_CUUID']
        TraceView::Config[:rum_id] = TraceView::Util::Base64URL.encode(Digest::SHA1.digest('RUM' + TraceView::Config[:access_key]))
      else
        # ..else read from system-wide configuration file
        if TraceView::Config.access_key.empty?
          config_file = '/etc/tracelytics.conf'
          return unless File.exist?(config_file)

          File.open(config_file).each do |line|
            if line =~ /^tracelyzer.access_key=/ || line =~ /^access_key/
              bits = line.split(/=/)
              TraceView::Config[:access_key] = bits[1].strip
              TraceView::Config[:rum_id] = TraceView::Util::Base64URL.encode(Digest::SHA1.digest('RUM' + TraceView::Config[:access_key]))
              break
            end
          end
        end
      end
    rescue StandardError => e
      TraceView.logger.error "Trouble obtaining access_key and rum_id: #{e.inspect}"
    end
  end
end

# Auto-start the Reporter unless we running Unicorn on Heroku
# In that case, we start the reporters after fork
unless TraceView.heroku? && TraceView.forking_webserver?
  TraceView::Reporter.start if TraceView.loaded
end
