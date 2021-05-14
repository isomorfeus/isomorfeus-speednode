# -*- coding: utf-8 -*-
require "minitest/autorun"
require "execjs/module"
require "json"

begin
  require "execjs"
rescue ExecJS::RuntimeUnavailable => e
  warn e
  exit 2
end

unless defined? Test
  if defined? Minitest::Test
    Test = Minitest::Test
  elsif defined? MiniTest::Unit::TestCase
    Test = MiniTest::Unit::TestCase
  end
end

class TestPermissiveExecJS < Test
  def test_runtime_available
    runtime = ExecJS::ExternalRuntime.new(command: "nonexistent")
    assert !runtime.available?

    runtime = ExecJS::ExternalRuntime.new(command: "ruby")
    assert runtime.available?
  end

  def test_runtime_assignment
    original_runtime = ExecJS.runtime
    runtime = ExecJS::ExternalRuntime.new(command: "nonexistent")
    assert_raises(ExecJS::RuntimeUnavailable) { ExecJS.runtime = runtime }
    assert_equal original_runtime, ExecJS.runtime

    runtime = ExecJS::ExternalRuntime.new(command: "ruby")
    ExecJS.runtime = runtime
    assert_equal runtime, ExecJS.runtime
  ensure
    ExecJS.runtime = original_runtime
  end

  def test_context_call
    context = ExecJS.permissive_compile("id = function(v) { return v; }")
    assert_equal "bar", context.call("id", "bar")
  end

  def test_nested_context_call
    context = ExecJS.permissive_compile("a = {}; a.b = {}; a.b.id = function(v) { return v; }")
    assert_equal "bar", context.call("a.b.id", "bar")
  end

  def test_call_with_complex_properties
    context = ExecJS.permissive_compile("")
    assert_equal 2, context.call("function(a, b) { return a + b }", 1, 1)

    context = ExecJS.permissive_compile("foo = 1")
    assert_equal 2, context.call("(function(bar) { return foo + bar })", 1)
  end

  def test_call_with_this
    # Known bug: https://github.com/cowboyd/therubyrhino/issues/39
    skip if ExecJS.runtime.is_a?(ExecJS::RubyRhinoRuntime)

    # Make sure that `this` is indeed the global scope
    context = ExecJS.permissive_compile(<<-EOF)
      name = 123;

      function Person(name) {
        this.name = name;
      }

      Person.prototype.getThis = function() {
        return this.name;
      }
    EOF

    assert_equal 123, context.call("(new Person('Bob')).getThis")
  end

  def test_context_call_missing_function
    context = ExecJS.permissive_compile("")
    assert_raises ExecJS::ProgramError do
      context.call("missing")
    end
  end

  {
    "function() {}" => nil,
    "0" => 0,
    "null" => nil,
    "undefined" => nil,
    "true" => true,
    "false" => false,
    "[1, 2]" => [1, 2],
    "[1, function() {}]" => [1, nil],
    "'hello'" => "hello",
    "'red yellow blue'.split(' ')" => ["red", "yellow", "blue"],
    "{a:1,b:2}" => {"a"=>1,"b"=>2},
    "{a:true,b:function (){}}" => {"a"=>true},
    "'café'" => "café",
    '"☃"' => "☃",
    '"\u2603"' => "☃",
    "'\u{1f604}'".encode("UTF-8") => "\u{1f604}".encode("UTF-8"), # Smiling emoji
    "'\u{1f1fa}\u{1f1f8}'".encode("UTF-8") => "\u{1f1fa}\u{1f1f8}".encode("UTF-8"), # US flag
    '"\\\\"' => "\\"
  }.each_with_index do |(input, output), index|
    define_method("test_exec_string_#{index}") do
      assert_output output, ExecJS.permissive_exec("return #{input}")
    end

    define_method("test_eval_string_#{index}") do
      assert_output output, ExecJS.permissive_eval(input)
    end

    define_method("test_compile_return_string_#{index}") do
      context = ExecJS.permissive_compile("var a = #{input};")
      assert_output output, context.permissive_eval("a")
    end

    define_method("test_compile_call_string_#{index}") do
      context = ExecJS.permissive_compile("function a() { return #{input}; }")
      assert_output output, context.call("a")
    end
  end

  [
    nil,
    true,
    false,
    1,
    3.14,
    "hello",
    "\\",
    "café",
    "☃",
    "\u{1f604}".encode("UTF-8"), # Smiling emoji
    "\u{1f1fa}\u{1f1f8}".encode("UTF-8"), # US flag
    [1, 2, 3],
    [1, [2, 3]],
    [1, [2, [3]]],
    ["red", "yellow", "blue"],
    { "a" => 1, "b" => 2},
    { "a" => 1, "b" => [2, 3]},
    { "a" => true }
  ].each_with_index do |value, index|
    json_value = JSON.generate(value, quirks_mode: true)

    define_method("test_json_value_#{index}") do
      assert_output value, JSON.parse(json_value, quirks_mode: true)
    end

    define_method("test_exec_value_#{index}") do
      assert_output value, ExecJS.permissive_exec("return #{json_value}")
    end

    define_method("test_eval_value_#{index}") do
      assert_output value, ExecJS.permissive_eval("#{json_value}")
    end

    define_method("test_strinigfy_value_#{index}") do
      context = ExecJS.permissive_compile("function json(obj) { return JSON.stringify(obj); }")
      assert_output json_value, context.call("json", value)
    end

    define_method("test_call_value_#{index}") do
      context = ExecJS.permissive_compile("function id(obj) { return obj; }")
      assert_output value, context.call("id", value)
    end
  end

  def test_additional_options
    assert ExecJS.permissive_eval("true", :foo => true)
    assert ExecJS.permissive_exec("return true", :foo => true)

    context = ExecJS.permissive_compile("foo = true", :foo => true)
    assert context.permissive_eval("foo", :foo => true)
    assert context.permissive_exec("return foo", :foo => true)
  end

  def test_eval_blank
    assert_nil ExecJS.permissive_eval("")
    assert_nil ExecJS.permissive_eval(" ")
    assert_nil ExecJS.permissive_eval("  ")
  end

  def test_exec_return
    assert_nil ExecJS.permissive_exec("return")
  end

  def test_exec_no_return
    assert_nil ExecJS.permissive_exec("1")
  end

  def test_encoding
    utf8 = Encoding.find('UTF-8')

    assert_equal utf8, ExecJS.permissive_exec("return 'hello'").encoding
    assert_equal utf8, ExecJS.permissive_eval("'☃'").encoding

    ascii = "'hello'".encode('US-ASCII')
    result = ExecJS.permissive_eval(ascii)
    assert_equal "hello", result
    assert_equal utf8, result.encoding

    assert_raises Encoding::UndefinedConversionError do
      binary = "\xde\xad\xbe\xef".force_encoding("BINARY")
      ExecJS.permissive_eval(binary)
    end
  end

  def test_encoding_compile
    utf8 = Encoding.find('UTF-8')

    context = ExecJS.permissive_compile("foo = function(v) { return '¶' + v; }".encode("ISO8859-15"))

    assert_equal utf8, context.permissive_exec("return foo('hello')").encoding
    assert_equal utf8, context.permissive_eval("foo('☃')").encoding

    ascii = "foo('hello')".encode('US-ASCII')
    result = context.permissive_eval(ascii)
    assert_equal "¶hello", result
    assert_equal utf8, result.encoding

    assert_raises Encoding::UndefinedConversionError do
      binary = "\xde\xad\xbe\xef".force_encoding("BINARY")
      context.permissive_eval(binary)
    end
  end

  def test_surrogate_pairs
    # Smiling emoji
    str = "\u{1f604}".encode("UTF-8")
    assert_equal 2, ExecJS.permissive_eval("'#{str}'.length")
    assert_equal str, ExecJS.permissive_eval("'#{str}'")

    # US flag emoji
    str = "\u{1f1fa}\u{1f1f8}".encode("UTF-8")
    assert_equal 4, ExecJS.permissive_eval("'#{str}'.length")
    assert_equal str, ExecJS.permissive_eval("'#{str}'")
  end

  def test_compile_anonymous_function
    context = ExecJS.permissive_compile("foo = function() { return \"bar\"; }")
    assert_equal "bar", context.permissive_exec("return foo()")
    assert_equal "bar", context.permissive_eval("foo()")
    assert_equal "bar", context.call("foo")
  end

  def test_compile_named_function
    context = ExecJS.permissive_compile("function foo() { return \"bar\"; }")
    assert_equal "bar", context.permissive_exec("return foo()")
    assert_equal "bar", context.permissive_eval("foo()")
    assert_equal "bar", context.call("foo")
  end

  def test_this_is_global_scope
    assert_equal true, ExecJS.permissive_eval("this === (function() {return this})()")
    assert_equal true, ExecJS.permissive_exec("return this === (function() {return this})()")
  end

  def test_browser_self_is_undefined
    assert ExecJS.permissive_eval("typeof self == 'undefined'")
  end

  def test_node_global_is_defined
    assert ExecJS.permissive_eval("typeof global == 'object'")
  end

  def test_node_process_object_is_defined
    assert ExecJS.permissive_eval("typeof process == 'object'")
    assert ExecJS.permissive_eval("'process' in this")
  end

  def test_some_commonjs_vars_are_defined
    assert ExecJS.permissive_eval("typeof module == 'undefined'")
    assert ExecJS.permissive_eval("typeof exports == 'undefined'")
    refute ExecJS.permissive_eval("typeof require == 'undefined'")

    refute ExecJS.permissive_eval("'module' in this")
    refute ExecJS.permissive_eval("'exports' in this")
    assert ExecJS.permissive_eval("'require' in this")
  end

  def test_console_is_defined
    refute ExecJS.permissive_eval("typeof console == 'undefined'")
    assert ExecJS.permissive_eval("'console' in this")
  end

  def test_some_timers_are_defined
    refute ExecJS.permissive_eval("typeof setTimeout == 'undefined'")
    assert ExecJS.permissive_eval("typeof setInterval == 'undefined'")
    refute ExecJS.permissive_eval("typeof clearTimeout == 'undefined'")
    assert ExecJS.permissive_eval("typeof clearInterval == 'undefined'")
    assert ExecJS.permissive_eval("typeof setImmediate == 'undefined'")
    assert ExecJS.permissive_eval("typeof clearImmediate == 'undefined'")

    assert ExecJS.permissive_eval("'setTimeout' in this")
    refute ExecJS.permissive_eval("'setInterval' in this")
    assert ExecJS.permissive_eval("'clearTimeout' in this")
    refute ExecJS.permissive_eval("'clearInterval' in this")
    refute ExecJS.permissive_eval("'setImmediate' in this")
    refute ExecJS.permissive_eval("'clearImmediate' in this")
  end

  def test_compile_large_scripts
    body = "var foo = 'bar';\n" * 100_000
    assert ExecJS.permissive_exec("function foo() {\n#{body}\n};\nreturn true")
  end

  def test_large_return_value
    string = ExecJS.permissive_eval('(new Array(100001)).join("abcdef")')
    assert_equal 600_000, string.size
  end

  def test_exec_syntax_error
    begin
      ExecJS.permissive_exec(")")
      flunk
    rescue ExecJS::RuntimeError => e
      assert e
      assert e.backtrace[0].include?("(execjs):1"), e.backtrace.join("\n")
    end
  end

  def test_eval_syntax_error
    begin
      ExecJS.permissive_eval(")")
      flunk
    rescue ExecJS::RuntimeError => e
      assert e
      assert e.backtrace[0].include?("(execjs):1"), e.backtrace.join("\n")
    end
  end

  def test_compile_syntax_error
    begin
      ExecJS.permissive_compile(")")
      flunk
    rescue ExecJS::RuntimeError => e
      assert e
      assert e.backtrace[0].include?("(execjs):1"), e.backtrace.join("\n")
    end
  end

  def test_exec_thrown_error
    begin
      ExecJS.permissive_exec("throw new Error('hello')")
      flunk
    rescue ExecJS::ProgramError => e
      assert e
      assert e.backtrace[0].include?("(execjs):1"), e.backtrace.join("\n")
    end
  end

  def test_eval_thrown_error
    begin
      ExecJS.permissive_eval("(function(){ throw new Error('hello') })()")
      flunk
    rescue ExecJS::ProgramError => e
      assert e
      assert e.backtrace[0].include?("(execjs):1"), e.backtrace.join("\n")
    end
  end

  def test_compile_thrown_error
    begin
      ExecJS.permissive_compile("throw new Error('hello')")
      flunk
    rescue ExecJS::ProgramError => e
      assert e
      assert e.backtrace[0].include?("(execjs):1"), e.backtrace.join("\n")
    end
  end

  def test_exec_thrown_string
    assert_raises ExecJS::ProgramError do
      ExecJS.permissive_exec("throw 'hello'")
    end
  end

  def test_eval_thrown_string
    assert_raises ExecJS::ProgramError do
      ExecJS.permissive_eval("(function(){ throw 'hello' })()")
    end
  end

  def test_compile_thrown_string
    assert_raises ExecJS::ProgramError do
      ExecJS.permissive_compile("throw 'hello'")
    end
  end

  # babel.js doesnt work as expected if global is defined
  #
  # def test_babel
  #   assert source = File.read(File.expand_path("../fixtures/babel.js", __FILE__))
  #   source = <<-JS
  #     var self = this;
  #     #{source}
  #     babel.eval = function(code) {
  #       return eval(babel.transform(code)["code"]);
  #     }
  #   JS
  #   context = ExecJS.permissive_compile(source)
  #   assert_equal 64, context.call("babel.eval", "((x) => x * x)(8)")
  # end

  def test_coffeescript
    assert source = File.read(File.expand_path("../fixtures/coffee-script.js", __FILE__))
    context = ExecJS.permissive_compile(source)
    assert_equal 64, context.call("CoffeeScript.eval", "((x) -> x * x)(8)")
  end

  def test_uglify
    assert source = File.read(File.expand_path("../fixtures/uglify.js", __FILE__))
    source = <<-JS
      #{source}

      function uglify(source) {
        var ast = UglifyJS.parse(source);
        var stream = UglifyJS.OutputStream();
        ast.print(stream);
        return stream.toString();
      }
    JS
    context = ExecJS.permissive_compile(source)
    assert_equal "function foo(bar){return bar}",
      context.call("uglify", "function foo(bar) {\n  return bar;\n}")
  end

  private

    def assert_output(expected, actual)
      if expected.nil?
        assert_nil actual
      else
        assert_equal expected, actual
      end
    end
end
