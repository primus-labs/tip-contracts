# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    foundry.url = "github:shazow/foundry.nix/stable";
  };

  outputs = { self, nixpkgs, utils, foundry }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ foundry.overlay ];
          config = { allowUnfree = true; };
        };
      in {

        devShell = with pkgs;
          mkShell {
            buildInputs = [
              # Web3 development tools
              foundry-bin
              solc

              # Other helpful utilities
              jq
            ];
          };
      });
}
