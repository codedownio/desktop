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

        frontend = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-frontend.tar.gz";
          sha256 = "sha256-YBnR68XBHFLpOQCpsPajaYVQcoksP2Wb+hJA75JvkeA=";
          stripRoot = false;
        };

        staticDocs = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-static-docs.tar.gz";
          sha256 = "sha256-UG+y5n433dKKvbCP0FXWk5DYOGjigzOxUxOPwCClaas=";
          stripRoot = false;
        };

        editor = util.packageBinary {
          name = "codedown-editor";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-editor";
            sha256 = "1by5dr83dhq11r9qgd9b886zyqvssf2173n876aiqr95m4bqka8p";
          };
        };

        runner = util.packageBinary {
          name = "codedown-runner";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-runner";
            sha256 = "0hp3k1x5njbc1r3fq3y3n6vanj1l201kzr62cbq4ng8d500h7f2q";
          };
        };

        server = util.packageBinary {
          name = "codedown-server";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-server";
            sha256 = "1xpx88cp1qkznkjj09wnmgv4910azyk3vb4i9aww8ffy457mwhn7";
          };
        };

      in rec {
        apps = {
          default = {
            type = "app";
            program = let
              script = with pkgs; writeShellScript "codedown-server.sh" ''
                ${server}/bin/codedown-server -c ${packages.default}
              '';
            in
              "${script}";
          };
        };

        packages = {
          default = pkgs.writeTextFile {
            name = "codedown-config.json";
            text = pkgs.callPackage ./config.nix {
              bootstrapNixpkgs = pkgs.path;
              inherit staticDocs;
              storeTemplate = pkgs.hello; # TODO
              inherit editor frontend runner templates;
            };
          };
        };
      });
}
