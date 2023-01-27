{
  description = "CodeDown Desktop";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        editor = pkgs.fetchurl {
          url = https://github.com/codedownio/desktop/releases/download/untagged-15151ff9fd7277ca25ce/codedown-editor;
          sha256 = "0ic3hn65dimgfhakli1cyf9j3cxcqsf1qib706ihfhmlzxf7257l";
        };

      in rec {
        apps = {

        };

        packages = {
          default = pkgs.writeTextFile {
            name = "codedown-config.json";
            text = pkgs.callPackage ./config.nix {
              inherit editor;
            };
          };
        };
      });
}
