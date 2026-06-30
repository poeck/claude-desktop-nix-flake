# Claude Desktop Nix Flake (Official Linux Beta)

[![Update Claude Desktop](https://github.com/poeck/claude-desktop-nix-flake/actions/workflows/update.yml/badge.svg)](https://github.com/poeck/claude-desktop-nix-flake/actions/workflows/update.yml)

Nix flake for Anthropic's official Claude Desktop Linux beta package.

This packages the real Linux build Anthropic ships through its Debian repository. It does not wrap the Windows app, does not unpack the macOS app, and does not depend on the older unofficial repacks.

## Why This Flake

- **Official upstream package**: builds from Anthropic's official `claude-desktop` Debian package for Linux.
- **No unofficial Electron repack**: uses the native Linux beta instead of repackaging the Windows or macOS release.
- **NixOS-ready**: includes a NixOS module, overlay, default package, and runnable app output.
- **Desktop integration included**: installs the upstream desktop entry, icons, and launcher.
- **Patched for Nix paths**: fixes Claude's native dependency lookups so the app can find Nix-provided QEMU, firmware, runtime libraries, and the bundled `virtiofsd`.
- **Automatic updates**: checks Anthropic's apt metadata every hour with GitHub Actions and commits verified version/hash updates when a new release appears.
- **Multi-architecture**: supports both `x86_64-linux` and `aarch64-linux`, matching Anthropic's published `amd64` and `arm64` packages.
- **Reproducible inputs**: pins the exact upstream `.deb` hashes in the derivation and keeps `nixpkgs` locked through `flake.lock`.

## Usage

Run directly:

```sh
nix run github:poeck/claude-desktop-nix-flake
```

Install with Nix profile:

```sh
nix profile install github:poeck/claude-desktop-nix-flake
```

Use as a NixOS module:

```nix
{
  inputs.claude-desktop-nix-flake.url = "github:poeck/claude-desktop-nix-flake";

  outputs = { nixpkgs, claude-desktop-nix-flake, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        claude-desktop-nix-flake.nixosModules.default
        {
          nixpkgs.config.allowUnfree = true;
          programs.claude-desktop.enable = true;
        }
      ];
    };
  };
}
```

Use as an overlay:

```nix
{
  nixpkgs.overlays = [ inputs.claude-desktop-nix-flake.overlays.default ];
  environment.systemPackages = [ pkgs.claude-desktop ];
}
```

## What This Packages

- Official package: `claude-desktop`
- Version: `1.17377.0`
- Architectures: `x86_64-linux`, `aarch64-linux`
- Source: `https://downloads.claude.ai/claude-desktop/apt/stable`

The derivation extracts the official `.deb`, patches native libraries for Nix, installs the desktop entry and icons, and patches Claude's Linux cowork VM dependency probes so they can find Nix-provided QEMU/firmware paths and the bundled `virtiofsd`.

## Notes

Claude Desktop is proprietary software. The Nix expressions in this repository are separate, but the packaged application itself is marked `unfree`.

If Chromium sandbox startup fails on a non-NixOS host with stricter user namespace policy, launch with:

```sh
claude-desktop --no-sandbox
```

That disables Chromium's sandbox and should only be used as a compatibility workaround.

## Updating

This repository includes a GitHub Actions workflow that checks for upstream Claude Desktop updates every hour and commits verified package updates automatically.

Run:

```sh
./scripts/update.sh
nix flake lock --update-input nixpkgs
nix build
```

The update script reads Anthropic's apt metadata, picks the newest shared version for `amd64` and `arm64`, and updates the pinned hashes in `pkgs/claude-desktop/default.nix`.

## Upstream

- Official Linux docs: <https://code.claude.com/docs/en/desktop-linux>
- Download page: <https://claude.com/download>
