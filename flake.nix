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
              sha256 = "0lmnv9wnjqcl6hni3l740mdvbccgxaflsipdkcn27gqr46fw4dni";
            };
          };
        in with pkgs; runCommand "codedown-screenshotter-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper ${screenshotterStatic}/bin/codedown-screenshotter "$out/bin/codedown-screenshotter" \
            --add-flags "--chrome-path ${pkgs.chromium}/bin/chromium"
        '';

        frontend = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-frontend-0.2.0.0.tar.gz";
          sha256 = "sha256-fQDDVldAorrL3UP2qbZFPBCitGKq2USJyGfVaHJDbCE=";
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
            sha256 = "0kyxvy9j1lz94p75ryb3kfnnnis0zwa0ii2xj9gyc6jfcslvpzqf";
          };
        };

        editor = with pkgs; runCommand "codedown-editor" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper "${server}/bin/codedown-server" "$out/bin/codedown-editor" \
            --set CODEDOWN_EXECUTABLE codedown-editor
        '';

        runner = with pkgs; runCommand "codedown-runner" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper "${server}/bin/codedown-server" "$out/bin/codedown-runner" \
            --set CODEDOWN_EXECUTABLE codedown-runner
        '';

        wrappedServer = with pkgs; runCommand "codedown-server-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper "${server}/bin/codedown-server" "$out/bin/codedown-server" \
            --prefix PATH : ${lib.makeBinPath [ nodejs nixCustom tmux rclone pkgsStatic.busybox bubblewrap editor screenshotter ]}
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
                mkdir -p "$CONFIG_DIR/local_stores"
                mkdir -p "$CONFIG_DIR/sandboxes"
                mkdir -p "$CONFIG_DIR/imports"

                ${wrappedServer}/bin/codedown-server -c "$CONFIG_FILE"
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
              defaultPackageStoreEnv = pkgs.hello; # TODO
              inherit staticDocs;

              inherit frontend runner templates;

              editorBinDir = with pkgs; runCommand "codedown-editor-bin-dir" {} ''
                mkdir -p $out
                cp -ra ${pkgsStatic.busybox}/bin/* $out
                # For some reason some busybox symlinks are "busybox" and some are "../bin/busybox".
                # Fix up the latter type.
                cd $out
                for file in $(find . -type l); do
                  ln -sf busybox "$file"
                done

                cp ${pkgsStatic.gnutar}/bin/tar $out/gnutar
              '';
            };
          };

          # Trying to debug "unexpected end-of-file" error from nix run
          test = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-screenshotter-0.1.0-x86_64-linux";
            sha256 = "0lmnv9wnjqcl6hni3l740mdvbccgxaflsipdkcn27gqr46fw4dni";
          };
        };
      });
}
