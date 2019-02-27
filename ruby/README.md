# isomorfeus-speednode

A fast runtime for execjs using node js.
Inspired by [execjs-fastnode](https://github.com/jhawthorn/execjs-fastnode).

### Chat
At our [Gitter Isomorfeus Lobby](http://gitter.im/isomorfeus/Lobby) 

### Installation

In Gemfile:
`gem 'isomorfeus-speednode'`, then `bundle install`

### Configuration

Isomorfeus-speednode provides 2 runtimes:
- `CompatibleSpeednode` - is compatible with the minimalistic execjs approach. Mainly intended for production/development usage.
- `PermissiveSpeednode` - allows for the usage of javascript commonjs 'require' and can handle circular objects from javascript world, to some extend.
Best used in spec/test environments.

`CompatibleSpeednode` is the default. The permissive runtime can be chosen by:

```ruby
ExecJS.runtime = ExecJS::Runtimes::PermissiveSpeednode
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

