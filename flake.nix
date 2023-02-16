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
          sha256 = "sha256-dagOy3gSr6TZVSkpzfj5vSzQEX5j0eDwb1GeIo1Mk98=";
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
            sha256 = "0qppp3ixnxlgil8gjm2rl5pdkyrc92kjqb0z3204wm6pkmij8841";
          };
        };

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

        runner = util.packageBinary {
          name = "codedown-runner";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-runner";
            sha256 = "14n9vgjmyi5kxqpkbffrbvvrig0v0fbwq8ga3kf8mq7h9wbp7dc0";
          };
        };

        server = util.packageBinary {
          name = "codedown-server";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-server";
            sha256 = "0m2vw7i00bjmfaax7wfjppw1mhwbss0sfiv767i5vdrmqbb87caa";
          };
        };

        nixCustom = util.packageBinary {
          name = "nix";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/nix-2.11.0-x86_64-linux";
            sha256 = "1b8wly6fha8w4724xdvpas41kxg2c4gwrvp23mfh8bjjd80ycqaa";
          };
        };

        screenshotterStatic = util.packageBinary {
          name = "codedown-screenshotter";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-screenshotter-0.1.0-x86_64-linux";
            sha256 = "0lmnv9wnjqcl6hni3l740mdvbccgxaflsipdkcn27gqr46fw4dni";
          };
        };

        screenshotter = with pkgs; runCommand "codedown-screenshotter-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper ${screenshotterStatic}/bin/codedown-screenshotter "$out/bin/codedown-screenshotter" \
            --add-flags "--chrome-path ${pkgs.chromium}/bin/chromium"
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

              inherit editorBinDir frontend runner templates;
            };
          };
        };
      });
}
