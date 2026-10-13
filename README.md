# ArcheAge Classic for Mac

ArcheAge Classic for Mac runs the official ArcheAge Classic launcher and game on Apple Silicon Macs.

It bundles a patched Wine runtime with MTLd3D (DirectX 9 on Metal), rosettax87 and a fix for the anti-cheat loader.

## Install

Download the DMG from Releases and drag the app to Applications. It isn't notarized yet, so macOS blocks it the first time. Go to System Settings, Privacy & Security, and click Open Anyway.

The first start takes a few minutes because it downloads its dependencies. After that it opens straight into the launcher. While you play it sits in the menu bar, which is where the preferences and logs are.

You need an Apple Silicon Mac on macOS 14 or newer. If Rosetta isn't installed, the app asks for it.

## Game settings

In the game's display options, keep Restrict Max FPS at 90 (the default for new installs; 60 saves power on a 60 Hz screen) and turn vertical sync off. With vsync on, a Mac that can't finish every frame in time for the display drops to half its refresh rate, so 60 on a 120 Hz panel even when it could manage 90 or more. Turn it back on only if you see tearing.
