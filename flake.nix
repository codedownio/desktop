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

        util = pkgs.callPackage ./util.nix {};

        editor = util.packageBinary {
          name = "codedown-editor";
          url = "https://github.com/codedownio/desktop/releases/download/v0.1.0.0/codedown-editor";
          sha256 = "sha256-F6mJF6klZRyVOciOE4TTemP/DUIrtYdTDgHDNlBuxa8=";
        };

        runner = pkgs.fetchurl {
          url = "https://github.com/codedownio/desktop/releases/download/v0.1.0.0/codedown-runner";
          sha256 = "sha256-WLgDASgNPUvwYsLkPwMQNEirtrHDD+xGDmxJW3qY40I=";
        };

        server = pkgs.fetchurl {
          url = "https://github.com/codedownio/desktop/releases/download/v0.1.0.0/codedown-server";
          sha256 = "sha256-e63+i6OtmldC8+zS6FmQ0+6uT5E9funUi8yTOwhZ90w=";
        };

      in rec {
        apps = {
          default = {
            type = "app";
            program = let
              script = with pkgs; writeShellScript "codedown-server.sh" ''
                ${server} -c ${packages.default}
              '';
            in
              "${script}";
          };
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
