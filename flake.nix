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

        nixCustom = util.packageBinary {
          name = "nix";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/nix-2.11.0-x86_64-linux";
            sha256 = "1b8wly6fha8w4724xdvpas41kxg2c4gwrvp23mfh8bjjd80ycqaa";
          };
        };

        screenshotter = let
          screenshotterStatic = util.packageBinary {
            name = "codedown-screenshotter";
            binary = pkgs.fetchurl {
              url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-screenshotter-0.1.0-x86_64-linux";
              sha256 = "1bxiyg3q8x3p0l0198s57h5b0rf9cgnfb2lw3lj9mzf8xzw6y5pl";
            };
          };
        in with pkgs; runCommand "codedown-screenshotter-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper ${screenshotterStatic}/bin/codedown-screenshotter "$out/bin/codedown-screenshotter" \
            --add-flags "--chrome-path ${pkgs.chromium}/bin/chromium"
        '';

        frontend = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-frontend-0.2.0.0.tar.gz";
          sha256 = "10nhhywxzqi7hm0qlw0l46pb9ld122dc7m4xzhqqcqvva7x353zb";
          stripRoot = false;
        };

        staticDocs = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-static-docs-0.2.0.0.tar.gz";
          sha256 = "1av9llhc13qkafqk70z2d0wdi44ksrax13xhpn5d5p9pgvkb4vsh";
          stripRoot = false;
        };

        server = util.packageBinary {
          name = "codedown-server";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-server-0.2.0.0-x86_64-linux";
            sha256 = "0g5n5lwcwzdh3rixklvm9ikz39am6wpr53ldqz2v40xznnawzviw";
          };
        };

        runner = with pkgs; runCommand "codedown-runner" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper "${server}/bin/codedown-server" "$out/bin/codedown-runner" \
            --set CODEDOWN_EXECUTABLE codedown-runner
        '';

        wrappedServer = with pkgs; runCommand "codedown-server-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper "${server}/bin/codedown-server" "$out/bin/codedown-server" \
            --prefix PATH : ${lib.makeBinPath [ nodejs nixCustom tmux rclone pkgsStatic.busybox bubblewrap slirp4netns screenshotter ]}
        '';

      in rec {
        apps = {
          default = {
            type = "app";
            program = let
              script = with pkgs; writeShellScript "codedown-server.sh" ''
                CONFIG_DIR=''${XDG_CONFIG_HOME:-$HOME/.config}/codedown

                if [ ! -d "CONFIG_DIR" ]; then
                  echo "Creating $CONFIG_DIR"
                  mkdir -p "$CONFIG_DIR"
                fi

                CONFIG_FILE="$CONFIG_DIR/config.json"
                if [ ! -f "CONFIG_FILE" ]; then
                  echo "Installing initial configuration to $CONFIG_FILE"
                  ${pkgs.gnused}/bin/sed "s|CODEDOWN_ROOT|$CONFIG_DIR|g" "${packages.default}" > "$CONFIG_FILE"
                fi

                # Make directories used by server
                mkdir -p "$CONFIG_DIR/local_runners"
                mkdir -p "$CONFIG_DIR/local_sandboxes"
                mkdir -p "$CONFIG_DIR/local_stores"
                mkdir -p "$CONFIG_DIR/sandboxes"
                mkdir -p "$CONFIG_DIR/imports"

                ${wrappedServer}/bin/codedown-server -c "$CONFIG_FILE" "$@"
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
              defaultPackageStoreEnv = pkgs.buildEnv {
                name = "codedown-default-package-store-environment";
                paths = with pkgs; [bashInteractive busybox tmux nixCustom fuse cacert nix-prefetch-git];
              };
              inherit staticDocs;

              inherit frontend runner templates;

              editorPath = "${server}/bin/codedown-server";

              editorBinDir = with pkgs; runCommand "codedown-editor-bin-dir" {} ''
                mkdir -p $out/bin
                cp -ra ${pkgsStatic.busybox}/bin/* $out/bin

                rm $out/bin/tar
                cp ${pkgsStatic.gnutar}/bin/tar $out/bin/tar
              '';
            };
          };
        };
      });
}
