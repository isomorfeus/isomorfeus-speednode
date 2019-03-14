module ExecJS
  class << self
    def permissive_exec(source, options = {})
      runtime.permissive_exec(source, options)
    end

    def permissive_eval(source, options = {})
      runtime.permissive_eval(source, options)
    end

    def permissive_compile(source, options = {})
      runtime.permissive_compile(source, options)
    end
  end
end
