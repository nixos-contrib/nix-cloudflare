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

        # nixpkgs' worker-build builds zstd-sys via pkg-config but doesn't provide libzstd.
        worker-build = pkgs.worker-build.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
          buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.zstd ];
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
