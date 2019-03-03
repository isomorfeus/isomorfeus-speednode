module Isomorfeus
  module Speednode
    PermissiveRuntime = Isomorfeus::Speednode::Runtime.new(
      name: 'Isomorfeus Speednode Permissive Node.js (V8)',
      command: %w[nodejs node],
      runner_path: File.join(File.dirname(__FILE__), 'speednode', 'permissive_runner.js'),
      encoding: 'UTF-8'
    )
    CompatibleRuntime = Isomorfeus::Speednode::Runtime.new(
      name: 'Isomorfeus Speednode Compatible Node.js (V8)',
      command: %w[nodejs node],
      runner_path: File.join(File.dirname(__FILE__), 'speednode', 'compatible_runner.js'),
      encoding: 'UTF-8'
    )
  end
end

module ExecJS
  module Runtimes
    PermissiveSpeednode = Isomorfeus::Speednode::PermissiveRuntime

    CompatibleSpeednode = Isomorfeus::Speednode::CompatibleRuntime

    runtimes << PermissiveSpeednode
    runtimes.unshift(CompatibleSpeednode)
  end
end
