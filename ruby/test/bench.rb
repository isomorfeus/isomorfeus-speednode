require 'bundler/setup'
Bundler.require
require 'mini_racer'
require 'execjs/fastnode'
require 'benchmark'

TIMES = 1000
CALL_TIMES = 1000
SOURCE = File.read(File.expand_path("../bench/coffee-script.js", __FILE__)).freeze
EXCLUDED_RUNTIMES = [ExecJS::Runtimes::Node, ExecJS::Runtimes::JavaScriptCore, ExecJS::Runtimes::V8, ExecJS::Runtimes::PermissiveSpeednode]

puts "standard ExecJS CoffeeScript call benchmark:"
Benchmark.bmbm do |x|
  ExecJS::Runtimes.runtimes.reject {|r| EXCLUDED_RUNTIMES.include?(r)}.each do |runtime|
    next if !runtime.available? || runtime.deprecated?

    x.report(runtime.name) do
      ExecJS.runtime = runtime
      context = ExecJS.compile(SOURCE)

      TIMES.times do
        context.call("CoffeeScript.eval", "((x) -> x * x)(8)")
      end
    end
  end
end

puts "\nCoffeeScript eval benchmark:"
Benchmark.bmbm do |x|
  ExecJS::Runtimes.runtimes.reject {|r| EXCLUDED_RUNTIMES.include?(r)}.each do |runtime|
    next if !runtime.available? || runtime.deprecated?

    x.report(runtime.name) do
      ExecJS.runtime = runtime
      context = ExecJS.compile(SOURCE)

      TIMES.times do
        context.eval("CoffeeScript.eval('((x) -> x * x)(8)')")
      end
    end
  end
end

puts "\neval overhead benchmark:"
Benchmark.bmbm do |x|
  ExecJS::Runtimes.runtimes.reject {|r| EXCLUDED_RUNTIMES.include?(r)}.each do |runtime|
    next if !runtime.available? || runtime.deprecated?

    x.report(runtime.name) do
      ExecJS.runtime = runtime
      context = ExecJS.compile('')

      CALL_TIMES.times do
        context.eval("true")
      end
    end
  end
end

puts "\ncall overhead benchmark:"
Benchmark.bmbm do |x|
  ExecJS::Runtimes.runtimes.reject {|r| EXCLUDED_RUNTIMES.include?(r)}.each do |runtime|
    next if !runtime.available? || runtime.deprecated?

    x.report(runtime.name) do
      ExecJS.runtime = runtime
      context = ExecJS.compile('')

      CALL_TIMES.times do
        context.call("(function(arg) {return arg;})","true")
      end
    end
  end
end