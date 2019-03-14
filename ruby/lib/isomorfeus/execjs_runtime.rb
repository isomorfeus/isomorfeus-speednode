module ExecJS
  # Abstract base class for runtimes
  class Runtime
    def permissive_exec(source, options = {})
      context = permissive_compile("", options)
      context.exec(source, options)
    end

    def permissive_eval(source, options = {})
      context = permissive_compile("", options)
      context.eval(source, options)
    end

    def permissive_compile(source, options = {})
      context_class.new(self, source, options.merge({permissive: true}))
    end
  end
end
