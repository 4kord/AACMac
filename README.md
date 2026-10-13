# ArcheAge Classic for Mac

ArcheAge Classic for Mac runs the official ArcheAge Classic launcher and game on Apple Silicon Macs.

It bundles a patched Wine runtime with MTLd3D (DirectX 9 on Metal), rosettax87 and a fix for the anti-cheat loader.

## Install

Download the DMG from Releases and drag the app to Applications. It isn't notarized yet, so macOS blocks it the first time. Go to System Settings, Privacy & Security, and click Open Anyway.

The first start takes a few minutes because it downloads its dependencies. After that it opens straight into the launcher. While you play it sits in the menu bar, which is where the preferences and logs are.

You need an Apple Silicon Mac on macOS 14 or newer. If Rosetta isn't installed, the app asks for it.

## Update

Quit the app from the menu bar, then drag the new version from the DMG into Applications and replace the old one. The game, your login and your settings stay. The first start after an update can take a minute while the app updates its parts, and macOS may ask you to allow it again under Privacy & Security.

## Uninstall

Quit the app, then run this in Terminal. It removes the app, the game and its settings.

```
rm -rf "/Applications/ArcheAge Classic.app" ~/Library/"Application Support/ArcheAge Classic" ~/Library/Logs/"ArcheAge Classic"
```

<img width="1512" height="982" alt="Screenshot 2026-10-13 at 6 17 57 PM" src="https://github.com/user-attachments/assets/eae32714-a4e9-4ab1-af8a-2e7365050c23" />
