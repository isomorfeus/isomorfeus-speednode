# isomorfeus-speednode

A fast runtime for execjs using node js. Works on Linux, BSDs, MacOS and Windows.
Inspired by [execjs-fastnode](https://github.com/jhawthorn/execjs-fastnode).

### Community and Support
At the [Isomorfeus Framework Project](http://isomorfeus.com) 

### Tested
[TravisCI](https://travis-ci.org): [![Build Status](https://travis-ci.org/isomorfeus/isomorfeus-speednode.svg?branch=master)](https://travis-ci.org/isomorfeus/isomorfeus-speednode)

### Installation

In Gemfile:
`gem 'isomorfeus-speednode'`, then `bundle install`

### Configuration

Isomorfeus-speednode provides one node based runtime `Speednode` which runs scripts in node vms.
The runtime can be chosen by:

```ruby
ExecJS.runtime = ExecJS::Runtimes::Speednode
```
If node cant find node modules for the permissive contexts (see below), its possible to set the load path before assigning the runtime:
```ruby
ENV['NODE_PATH'] = './node_modules'
```

### Contexts

Each ExecJS context runs in a node vm. Speednode offers two kinds of contexts:
- a compatible context, which is compatible with default ExecJS behavior.
- a permissive context, which is more permissive and allows to `require` node modules.

#### Compatible
A compatible context can be created with the standard `ExecJS.compile` or code can be executed within a compatible context by using the standard `ExecJS.eval` or `ExecJS.exec`.
Example for a compatible context:
```ruby
compat_context = ExecJS.compile('Test = "test"')
compat_context.eval('1+1')
```
#### Permissive 
A permissive context can be created with `ExecJS.permissive_compile` or code can be executed within a permissive context by using  
`ExecJS.permissive_eval` or `ExecJS.permissive_exec`.
Example for a permissive context:
```ruby
perm_context = ExecJS.permissive_compile('Test = "test"')
perm_context.eval('1+1')
```
Evaluation in a permissive context:
```ruby
ExecJS.permissive_eval('1+1')
```

### Benchmarks

Highly scientific, maybe.

1000 rounds on Linux using node 16.1.0:
```
standard ExecJS CoffeeScript call benchmark:
                                        user     system      total        real
Node.js (V8) fast                   0.234199   0.093775   0.327974 (  0.877142)
Isomorfeus Speednode Node.js (V8)   0.108882   0.048014   0.156896 (  0.587261)
mini_racer (V8)                     0.801764   0.105020   0.906784 (  0.515463)
Node.js (V8)                        0.420842   0.293893  52.471348 ( 50.990930)

call overhead benchmark:
                                        user     system      total        real
Node.js (V8) fast                   0.192230   0.086253   0.278483 (  0.372702)
Isomorfeus Speednode Node.js (V8)   0.101266   0.034985   0.136251 (  0.214831)
mini_racer (V8)                     0.163080   0.052209   0.215289 (  0.141151)
Node.js (V8)                        0.354932   0.218117  29.016030 ( 28.410343)
```

1000 rounds on Windows 10 using node 16.1.0:
```
standard ExecJS CoffeeScript call benchmark:
                                        user     system      total        real
Isomorfeus Speednode Node.js (V8)   0.031000   0.016000   0.047000 (  0.548920)
Node.js (V8)                        1.172000   2.594000   3.766000 ( 91.619422)

call overhead benchmark:
                                        user     system      total        real
Isomorfeus Speednode Node.js (V8)   0.063000   0.000000   0.063000 (  0.162426)
Node.js (V8)                        0.656000   2.516000   3.172000 ( 63.766556)
```

To run benchmarks:
- clone repo
- `bundle install`
- `bundle exec rake bench`

### Tests
To run tests:
- clone repo
- `bundle install`
- `bundle exec rake test`