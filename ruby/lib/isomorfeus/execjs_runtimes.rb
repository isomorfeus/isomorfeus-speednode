module ExecJS
  module Runtimes
    Speednode = Isomorfeus::Speednode::Runtime.new(
      name: 'Isomorfeus Speednode Node.js (V8)',
      command: %w[nodejs node],
      runner_path: File.join(File.dirname(__FILE__), 'speednode', 'runner.js'),
      encoding: 'UTF-8'
    )
    runtimes.unshift(Speednode)
  end
end
