require 'securerandom'
if Gem.win_platform?
  require 'win32/pipe'

  module Win32
    class Pipe
      def write(data)
        bytes = FFI::MemoryPointer.new(:ulong)

        raise Error, "no pipe created" unless @pipe

        if @asynchronous
          bool = WriteFile(@pipe, data, data.bytesize, bytes, @overlapped)
          bytes_written = bytes.read_ulong

          if bool && bytes_written > 0
            @pending_io = false
            return true
          end

          error = GetLastError()
          if !bool && error == ERROR_IO_PENDING
            @pending_io = true
            return true
          end

          return false
        else
          unless WriteFile(@pipe, data, data.bytesize, bytes, nil)
            raise SystemCallError.new("WriteFile", FFI.errno)
          end

          return true
        end
      end
    end
  end
end

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
          message = message + "\x04"
          bytes_to_send = message.bytesize
          sent_bytes = 0

          if ExecJS.windows?
            @socket.write(message)
            begin
              result << @socket.read
            end until result.end_with?("\x04")
          else
            sent_bytes = @socket.sendmsg(message)
            if sent_bytes < bytes_to_send
              while sent_bytes < bytes_to_send
                sent_bytes += @socket.sendmsg(message.byteslice((sent_bytes)..-1))
              end
            end
            
            begin
              result << @socket.recvmsg()[0]
            end until result.end_with?("\x04")
          end
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
          if ExecJS.windows?
            @socket_dir = nil
            @socket_path = SecureRandom.uuid
          else
            @socket_dir = Dir.mktmpdir("isomorfeus-speednode-")
            @socket_path = File.join(@socket_dir, "socket")
          end
          @pid = Process.spawn({"SOCKET_PATH" => @socket_path}, @options[:binary], @options[:runner_path])

          retries = 20

          if ExecJS.windows?
            timeout_or_connected = false
            begin
              retries -= 1 
              begin
                @socket = Win32::Pipe::Client.new(@socket_path, Win32::Pipe::ACCESS_DUPLEX)
              rescue
                sleep 0.1
                raise "Unable to start nodejs process in time" if retries == 0
                next
              end
              timeout_or_connected = true
            end until timeout_or_connected
          else
            while !File.exist?(@socket_path)
              sleep 0.1
              retries -= 1
              raise "Unable to start nodejs process in time" if retries == 0
            end

            @socket = UNIXSocket.new(@socket_path)
          end

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
          eval "#{identifier}.apply(this, #{::Oj.dump(args, mode: :strict)})"
        end

        def eval(source, options = {})
          raw_exec("(#{source})") if /\S/ =~ source
        end

        def exec(source, options = {})
          raw_exec("(function(){#{source}})()")
        end

        def permissive?
          @permissive
        end

        def permissive_eval(source, options = {})
          raw_execp("(#{source})") if /\S/ =~ source
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
