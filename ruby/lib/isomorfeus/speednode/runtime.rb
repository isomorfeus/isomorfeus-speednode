module Isomorfeus
  module Speednode
    class Runtime < ExecJS::Runtime
      class VMCommand
        def initialize(socket, cmd, arguments)
          @socket = socket
          @cmd = cmd
          @arguments = arguments
        end

        def execute
          result = ''
          message = ::Oj.dump({ 'cmd' => @cmd, 'args' => @arguments }, mode: :strict)
          @socket.sendmsg(message + "\x04")
          begin
            result << @socket.recvmsg()[0]
          end until result.end_with?("\x04")
          ::Oj.load(result.chop!, create_additions: false)
        end
      end

      class VM
        def initialize(options)
          @mutex = Mutex.new
          @socket_path = nil
          @options = options
          @started = false
          @socket = nil
        end

        def started?
          @started
        end

        def self.finalize(socket, socket_dir, socket_path, pid)
          proc { exit_node(socket, socket_dir, socket_path, pid) }
        end

        def self.exit_node(socket, socket_dir, socket_path, pid)
          VMCommand.new(socket, "exit", [0]).execute
          socket.close
          File.unlink(socket_path)
          Dir.rmdir(socket_dir)
          Process.kill('KILL', pid)
        end

        def exec(context, source)
          command("exec", {'context' => context, 'source' => source})
        end

        def execp(context, source)
          command("execp", {'context' => context, 'source' => source})
        end

        def delete_context(context)
          command("deleteContext", context)
        end

        def start
          @mutex.synchronize do
            start_without_synchronization
          end
        end

        private

        def start_without_synchronization
          return if @started
          @socket_dir = Dir.mktmpdir("isomorfeus-speednode-")
          @socket_path = File.join(@socket_dir, "socket")
          @pid = Process.spawn({"SOCKET_PATH" => @socket_path}, @options[:binary], @options[:runner_path])

          retries = 20
          while !File.exist?(@socket_path)
            sleep 0.05
            retries -= 1

            if retries == 0
              raise "Unable to start nodejs process in time"
            end
          end

          @socket = UNIXSocket.new(@socket_path)
          @started = true

          at_exit do
            begin
              self.class.exit_node(@socket, @socket_dir, @socket_path, @pid) unless @socket.closed?
            rescue
              # do nothing
            end
          end

          ObjectSpace.define_finalizer(self, self.class.finalize(@socket, @socket_dir, @socket_path, @pid))
        end

        def command(cmd, *arguments)
          @mutex.synchronize do
            start_without_synchronization
            VMCommand.new(@socket, cmd, arguments).execute
          end
        end
      end

      class Context < ::ExecJS::Runtime::Context
        def initialize(runtime, source = "", options = {})
          @runtime = runtime
          @uuid = SecureRandom.uuid
          @permissive = !!options[:permissive]

          ObjectSpace.define_finalizer(self, self.class.finalize(@runtime, @uuid))

          begin
            source = encode(source)
          rescue
            source = source.force_encoding('UTF-8')
          end

          @permissive ? raw_execp(source) : raw_exec(source)
        end

        def self.finalize(runtime, uuid)
          proc { runtime.vm.delete_context(uuid) }
        end

        def call(identifier, *args)
          eval "#{identifier}.apply(this, #{::Oj.dump(args)})"
        end

        def eval(source, options = {})
          if /\S/ =~ source
            raw_exec("(#{source})")
          end
        end

        def exec(source, options = {})
          raw_exec("(function(){#{source}})()")
        end

        def permissive?
          @permissive
        end

        def permissive_eval(source, options = {})
          if /\S/ =~ source
            raw_execp("(#{source})")
          end
        end

        def permissive_exec(source, options = {})
          raw_execp("(function(){#{source}})()")
        end

        def raw_exec(source)
          source = encode(source)

          result = @runtime.vm.exec(@uuid, source)
          extract_result(result)
        end

        def raw_execp(source)
          source = encode(source)

          result = @runtime.vm.execp(@uuid, source)
          extract_result(result)
        end

        protected

        def extract_result(output)
          status, value, stack = output
          if status == "ok"
            value
          else
            stack ||= ""
            stack = stack.split("\n").map do |line|
              line.sub(" at ", "").strip
            end
            stack.reject! { |line| ["eval code", "eval@[native code]"].include?(line) }
            stack.shift unless stack[0].to_s.include?("(execjs)")
            error_class = value =~ /SyntaxError:/ ? ExecJS::RuntimeError : ExecJS::ProgramError
            error = error_class.new(value)
            error.set_backtrace(stack + caller)
            raise error
          end
        end
      end

      attr_reader :name, :vm

      def initialize(options)
        @name        = options[:name]
        @binary      = Isomorfeus::Speednode::NodeCommand.cached(options[:command])
        @runner_path = options[:runner_path]
        @encoding    = options[:encoding]
        @deprecated  = !!options[:deprecated]

        @vm = VM.new(
          binary: @binary,
          runner_path: @runner_path
        )

        @popen_options = {}
        @popen_options[:external_encoding] = @encoding if @encoding
        @popen_options[:internal_encoding] = ::Encoding.default_internal || 'UTF-8'
      end

      def available?
        @binary ? true : false
      end

      def deprecated?
        @deprecated
      end
    end
  end
end
