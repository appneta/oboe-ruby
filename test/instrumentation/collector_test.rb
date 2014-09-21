require 'minitest_helper'

GC::Profiler.enable if RUBY_VERSION >= '1.9.3'

describe Oboe::Collector do
  before do
    clear_all_traces
  end

  after do
  end

  it 'should be loaded, defined, instantiated and ready' do
    defined?(::Oboe::Collector).wont_match nil
    Oboe.collector.wont_match nil
  end

  it 'should have correct default Oboe::Config values' do
    Oboe::Config[:collector][:enabled].must_equal true
    Oboe::Config[:collector][:sleep_interval].must_equal 60
  end

  it 'should generate metric traces' do
    Oboe.collector.start

    # Allow the thread to spawn, collect and report
    # metrics
    sleep 2

    traces = get_all_traces
    traces.count.must_equal 3

    validate_outer_layers(traces, 'RubyMetrics')

    traces[1]['Layer'].must_equal "RubyMetrics"
    traces[1]['Label'].must_equal "metrics"

    traces[1].has_key?('count').must_equal true
    traces[1].has_key?('heap_live_slot').must_equal true
    traces[1].has_key?('heap_free_slot').must_equal true
    traces[1].has_key?('total_allocated_object').must_equal true
    traces[1].has_key?('total_freed_object').must_equal true
    traces[1].has_key?('minor_gc_count').must_equal true
    traces[1].has_key?('major_gc_count').must_equal true
    traces[1]['RubyVersion'].must_equal RUBY_VERSION
    traces[1].has_key?('ThreadCount').must_equal true
    traces[1].has_key?('VmRSS').must_equal true

    Oboe.collector.stop
  end
end
