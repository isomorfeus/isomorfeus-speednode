# isomorfeus-speednode

A fast runtime for execjs using node js.
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
A compatible context can be created with the standard `ExecJS.compile` or code can be executed within a compatible context by using the standard 
`ExecJS.eval` or `ExecJS.exec`.
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
```
standard ExecJS CoffeeScript call benchmark, but 1000 rounds:
                                                   user     system      total        real
Isomorfeus Speednode Compatible Node.js (V8)   0.042263   0.017215   0.059478 (  0.442855)
Node.js (V8) fast                              0.222875   0.087109   0.309984 (  0.806736)
mini_racer (V8)                                0.425273   0.013478   0.438751 (  0.304434)


call overhead benchmark, 1000 rounds:
                                                   user     system      total        real
Isomorfeus Speednode Compatible Node.js (V8)   0.023060   0.010358   0.033418 (  0.059640)
Node.js (V8) fast                              0.191454   0.081396   0.272850 (  0.368568)
mini_racer (V8)                                0.017091   0.002494   0.019585 (  0.019584)
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