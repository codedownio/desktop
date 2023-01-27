{
  description = "CodeDown Desktop";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";

  inputs.templates.url = "github:codedownio/templates";
  inputs.templates.flake = false;

  outputs = { self, flake-utils, nixpkgs, templates }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        editor = with pkgs; let
          binary = fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.1.0.0/codedown-editor";
            sha256 = "sha256-F6mJF6klZRyVOciOE4TTemP/DUIrtYdTDgHDNlBuxa8=";
          };
          in
            runCommand "codedown-editor" {} ''
              mkdir -p $out/bin
              cp ${binary} $out/bin/codedown-editor
            '';

        runner = pkgs.fetchurl {
          url = "https://github.com/codedownio/desktop/releases/download/v0.1.0.0/codedown-runner";
          sha256 = "sha256-F6mJF6klZRyVOciOE4TTemP/DUIrtYdTDgHDNlBuxa7=";
        };

      in rec {
        apps = {

        };

        packages = {
          default = pkgs.writeTextFile {
            name = "codedown-config.json";
            text = pkgs.callPackage ./config.nix {
              inherit templates editor runner;
            };
          };
        };
      });
}
