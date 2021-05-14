require 'bundler/setup'
Bundler.require
unless Gem.win_platform?
  require 'mini_racer'
  require 'execjs/fastnode'
end
require 'benchmark'

TIMES = 1000
CALL_TIMES = 1000
SOURCE = File.read(File.expand_path("./fixtures/coffee-script.js", File.dirname(__FILE__))).freeze
EXCLUDED_RUNTIMES = [ExecJS::Runtimes::JavaScriptCore, ExecJS::Runtimes::V8, ExecJS::Runtimes::JScript]

puts "Standard ExecJS CoffeeScript call benchmark:"
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

puts "\nEval overhead benchmark:"
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

puts "\nCall overhead benchmark:"
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

puts "\nPermissive: standard ExecJS CoffeeScript call benchmark:"
Benchmark.bmbm do |x|
  x.report(ExecJS::Runtimes::Speednode.name) do
    ExecJS.runtime = ExecJS::Runtimes::Speednode
    context = ExecJS.permissive_compile(SOURCE)

    TIMES.times do
      context.call("CoffeeScript.eval", "((x) -> x * x)(8)")
    end
  end
end

puts "\nPermissive: CoffeeScript eval benchmark:"
Benchmark.bmbm do |x|
  x.report(ExecJS::Runtimes::Speednode.name) do
    ExecJS.runtime = ExecJS::Runtimes::Speednode
    context = ExecJS.permissive_compile(SOURCE)

    TIMES.times do
      context.eval("CoffeeScript.eval('((x) -> x * x)(8)')")
    end
  end
end

puts "\nPermissive: eval overhead benchmark:"
Benchmark.bmbm do |x|
  x.report(ExecJS::Runtimes::Speednode.name) do
    ExecJS.runtime = ExecJS::Runtimes::Speednode
    context = ExecJS.permissive_compile('')

    CALL_TIMES.times do
      context.eval("true")
    end
  end
end

puts "\nPermissive: call overhead benchmark:"
Benchmark.bmbm do |x|
  x.report(ExecJS::Runtimes::Speednode.name) do
    ExecJS.runtime = ExecJS::Runtimes::Speednode
    context = ExecJS.permissive_compile('')

    CALL_TIMES.times do
      context.call("(function(arg) {return arg;})","true")
    end
  end
end