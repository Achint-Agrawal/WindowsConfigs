# WezTerm

`setup-windows.ps1` links `~\.wezterm.lua` to `wezterm.lua` in this
directory. The default shell is PowerShell 7, with JetBrainsMono Nerd Font,
ligatures, and zero window padding.

## Rendering

The configuration uses WebGPU, preferring a discrete hardware adapter when
available. CPU-only machines retain WebGPU with reduced cursor/blink
animation work.
The interactive frame-rate limit remains at WezTerm's default of 60 FPS.

On this Hyper-V/Remote Desktop machine, WebGPU exposes only the CPU-based
Microsoft Basic Render Driver. Forcing WebGPU does not provide hardware
acceleration here.

The software frontend fails to open a window on this machine with
"The OpenGL implementation is too old to work with glium". WebGPU's
DirectX 12 backend is required even though its available adapter is CPU-based.

After a renderer change, save work and fully exit/relaunch WezTerm;
restarting Neovim or opening another tab is not enough to ensure the new
renderer is used. See
`..\troubleshooting\wezterm-cpu-rendering-lag.md` for diagnosis and
comparison steps.

## Keyboard shortcuts

The terminal leader is `Ctrl+Shift+Space`, followed by the listed key.

| Key | Action |
| --- | --- |
| Leader, `Shift+\` | Split right |
| Leader, `-` | Split down |
| `Ctrl+h/j/k/l` | Move between terminal panes |
| `Alt+h/j/k/l` | Resize terminal panes |
| Leader, `z` | Zoom the current pane |
| Leader, `x` | Close the current pane, with confirmation |
| Leader, `c` | New tab |
| Leader, `w` | Tab navigator |
| `Ctrl+Shift+C` / `Ctrl+Shift+V` | Copy / paste |
| `Ctrl+Shift+L` | Debug overlay |

## Neovim

Launch `nvim` normally from PowerShell. The same LazyVim configuration,
C# language server, file navigation, and clipboard shortcuts apply in
WezTerm and Windows Terminal.

`Ctrl+h/j/k/l` are reserved for WezTerm panes. Use `Ctrl+w`, then
`h/j/k/l`, to navigate Neovim splits. `Ctrl+.` is forwarded to Neovim's
Sidekick shortcut.
