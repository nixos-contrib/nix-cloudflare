{
  description = "nix-cloudflare - Cloudflare-native Nix binary cache using Workers, R2, and Rust.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      rust-overlay,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        # nixpkgs builds the -sys crates against system libraries since its November
        # release, and zstd-sys finds no libzstd: let it build its own bundled copy.
        worker-build = pkgs.worker-build.overrideAttrs (old: rec {
          # nixpkgs has 0.8.7, which refuses worker 0.9.
          version = "0.9.0";
          src = pkgs.fetchFromGitHub {
            owner = "cloudflare";
            repo = "workers-rs";
            tag = "v${version}";
            hash = "sha256-zmeQp7db2rwfECp9p5NthKvzsZFnQPFO+eueIhFsIwE=";
            fetchSubmodules = true;
          };
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit src;
            name = "worker-build-${version}-vendor";
            hash = "sha256-EbRwSrxRys2EcDfB88apmH5Rm0NUWLKtmGPS77fAhpI=";
          };
          dontCargoUseSystemLibs = true;
        });
      in
      {
        devShells.default = pkgs.mkShell {
          name = "nix-cloudflare";
          packages = [
            pkgs.nodejs
            pkgs.opentofu
            pkgs.pkg-config
            pkgs.wrangler
            worker-build
            rust-toolchain
          ];
        };
      }
    );
}
