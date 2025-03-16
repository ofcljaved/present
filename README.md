# `present.nvim`

This is a plugin to show markdown as slides

# Features: Neovim lua execution

Can execute code in lua blocks, when you have them in a slide

```lua
print("Hello World", 37)
```
# Features: Other Langs

Can execute code in Language blocks, when you have them in a slide

Yoy may need to configure this with `opts.executors`, only have javascript vy default.

```javascript
console.log("Hello World", 37);
```
# Usage 

```lua
require("present").start_presentation {}
```
or use `:PresentStart` command

Use `n` and `p` to navigate through slides
and use `q` to quit out of it 

# Credits

teej_dv

### P.S. Still learning
