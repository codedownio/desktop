{
  description = "CodeDown Desktop";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";

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
            url = "https://github.com/codedownio/desktop/releases/download/v1.4.0/nix-2.16.2-x86_64-linux";
            hash = "sha256-xlxF970lz69xsh96BHC/qiZMOqnOXn/LR9FfwV8Gn2s=";
          };
        };

        screenshotter = let
          screenshotterStatic = util.packageBinary {
            name = "codedown-screenshotter";
            binary = pkgs.fetchurl {
              url = "https://github.com/codedownio/desktop/releases/download/v1.4.0/codedown-screenshotter-0.1.0-x86_64-linux";
              hash = "sha256-cm3XDD9Ew7W7hb+URVwmH16VSO2XLx5U1rJk9c140Lo=";
            };
          };
        in with pkgs; runCommand "codedown-screenshotter-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper ${screenshotterStatic}/bin/codedown-screenshotter "$out/bin/codedown-screenshotter" \
            --add-flags "--chrome-path ${pkgs.chromium}/bin/chromium"
        '';

        frontend = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v1.4.0/codedown-frontend-1.4.0.tar.gz";
          hash = "sha256-UnyordwgSIhKlkfDuQhG/BhXHDk7GoXIhZxAC2uWFVY=";
          stripRoot = false;
        };

        staticDocs = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v1.4.0/codedown-static-docs-1.4.0.tar.gz";
          hash = "sha256-+u2VTmOstTPh2d5vtwskGUc8sLacpgAt4acrl9lEYRw=";
          stripRoot = false;
        };

        server = util.packageBinary {
          name = "codedown-server";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v1.4.0/codedown-server-1.4.0-x86_64-linux";
            hash = "sha256-cBhTzI10BKFc1uVoGq+ejivQq+jPFbqYKOH0TIrzz9U=";
          };
        };

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
                mkdir -p "$CONFIG_DIR/gc_roots"
                mkdir -p "$CONFIG_DIR/imports"
                mkdir -p "$CONFIG_DIR/local_runners"
                mkdir -p "$CONFIG_DIR/local_sandboxes"
                mkdir -p "$CONFIG_DIR/local_stores"
                mkdir -p "$CONFIG_DIR/sandboxes"

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

              inherit frontend templates;

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
