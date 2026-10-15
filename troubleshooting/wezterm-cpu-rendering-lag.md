# WezTerm typing and scrolling lag on a CPU-only Windows desktop

## Symptom

Neovim typing, cursor movement, and scrolling feel slower in WezTerm than
in Windows Terminal, even after Roslyn has finished loading the solution.

Changing the renderer to `Software` then prevents WezTerm from opening.
The startup log reports:

```text
Failed to create window: The OpenGL implementation is too old to work with glium
```

## Root cause

`wezterm\wezterm.lua` uses `front_end = "WebGpu"` with a high-performance
adapter preference.

On this machine, `wezterm.gui.enumerate_gpus()` reports only a DirectX 12
adapter named Microsoft Basic Render Driver with `device_type = "Cpu"`.
Windows exposes Hyper-V and Remote Display adapters, not a hardware GPU.
WebGPU therefore uses CPU-based GPU emulation rather than hardware
acceleration. A high-performance preference cannot create a hardware GPU.

The CPU-backed renderer is a possible contributor to the
reported interactive lag, not proof that all performance differences
come from the renderer. Language-server operations are a separate workload.

The attempted `Software` frontend still encounters an OpenGL requirement
in the installed WezTerm 20240203 build. This VM's OpenGL implementation
is too old for glium, so that frontend cannot create a window. Configuration
parsing succeeds; the error happens only during actual GUI startup.

## Fix

`wezterm\wezterm.lua` retains WebGPU so its DirectX 12 backend can create
a window without the unsupported OpenGL implementation. It prefers a
discrete hardware adapter when available. With no hardware GPU, it retains
WebGPU's CPU-backed adapter with `animation_fps = 1` and constant cursor
blink transitions.

The default 60 FPS interactive redraw limit, font, ligatures, PowerShell
shell, and terminal shortcuts are preserved. No Neovim or Roslyn features
are disabled.

Save work and fully exit/relaunch WezTerm to apply the renderer change.
Compare typing, cursor movement, and scrolling in the same file and at
the same terminal dimensions after solution loading finishes.

## Prevention

- Do not assume that a WebGPU adapter provides hardware acceleration;
  check its `device_type`.
- In the debug overlay (`Ctrl+Shift+L`), evaluate
  `wezterm.gui.enumerate_gpus()` to inspect available adapters.
- Use low animation rates with a CPU renderer rather than lowering the
  interactive redraw rate.
- Verify actual GUI startup after changing renderers; a successful
  `wezterm show-keys` configuration check does not validate window creation.
- If lag remains, profile Neovim and compare terminal redraw costs before
  changing language-server settings.

## References

- [WezTerm render front ends](https://wezterm.org/config/lua/config/front_end.html)
- [WebGPU adapter selection](https://wezterm.org/config/lua/config/webgpu_preferred_adapter.html)
- [Animation rate guidance for CPU renderers](https://wezterm.org/config/lua/config/animation_fps.html)
