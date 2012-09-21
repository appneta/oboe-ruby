Gem::Specification.new do |s|
    s.name = %q{oboe}
    s.version = "1.3.0"
    s.date = %{2012-09-12}
    s.authors = ["Tracelytics, Inc."]
    s.email = %q{contact@tracelytics.com}
    s.summary = %q{Tracelytics instrumentation gem}
    s.homepage = %q{http://tracelytics.com}
    s.description = %q{The oboe gem provides Tracelytics instrumentation for Ruby and Ruby frameworkes.}
    s.extra_rdoc_files = ["LICENSE"]
    s.files = Dir.glob(File.join('lib', '**', '*.rb')) + Dir.glob(File.join('ext/oboe_metal', '**', '*.{c,cxx,hpp}')) + ['install.rb', 'init.rb', "LICENSE"]
    s.extensions = ['ext/oboe_metal/extconf.rb']
end
