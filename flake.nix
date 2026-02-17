{
  description = "CodeDown Desktop";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";

  inputs.templates.url = "github:codedownio/templates";
  inputs.templates.flake = false;

  outputs = { self, flake-utils, nixpkgs, templates }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        util = pkgs.callPackage ./util.nix {};

        nixBinaries = {
          x86_64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v1.7.1/nix-2.32.4-x86_64-linux";
            hash = "sha256-dD3tVE25Xf9vRqYyUJFLgdIkZVGnaMMPgpbxIvhmyoM=";
          };
          aarch64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v1.7.1/nix-2.32.4-aarch64-linux";
            hash = "sha256-KuRcDsI3hPuQYMhVqmPld1cxgUyA1/B98+XMKTZtbwc=";
          };
        };

        serverTarballs = {
          x86_64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v1.7.1/codedown-server-1.7.1-x86_64-linux.tar.gz";
            hash = "sha256-bL/IW4HZucr/Sclz6ogEGctAdu03ZXjv9WIIN7Ch37Q=";
            stripRoot = true;
            binaryPath = "codedown-server";
          };
          aarch64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v1.7.1/codedown-server-1.7.1-aarch64-linux.tar.gz";
            hash = "sha256-GqVyM6z137I7QpLtWuLwsq5GsTgR5XXnkKX1Pi1dBiY=";
            stripRoot = false;
            binaryPath = "bin/codedown-server";
          };
        };

        screenshotterBinaries = {
          x86_64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v1.7.1/codedown-screenshotter-0.1.1-x86_64-linux";
            hash = "sha256-hWfRjeUwLlmN5LvL1qQTp9zrOELgh6EJ6vDNKjb6Mjw=";
          };
          aarch64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v1.7.1/codedown-screenshotter-0.1.1-aarch64-linux";
            hash = "sha256-lpd4rpURBeCfaAtbpLzSBWwTcplgKqkR5XoGbUd1vmI=";
          };
        };

        nixCustom = util.packageBinary {
          name = "nix";
          binary = pkgs.fetchurl nixBinaries.${system};
        };

        server = pkgs.fetchzip {
          url = serverTarballs.${system}.url;
          hash = serverTarballs.${system}.hash;
          stripRoot = serverTarballs.${system}.stripRoot;
        };

        screenshotter = let
          screenshotterStatic = util.packageBinary {
            name = "codedown-screenshotter";
            binary = pkgs.fetchurl screenshotterBinaries.${system};
          };
        in with pkgs; runCommand "codedown-screenshotter-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper ${screenshotterStatic}/bin/codedown-screenshotter "$out/bin/codedown-screenshotter" \
            --add-flags "--chrome-path ${pkgs.chromium}/bin/chromium"
        '';

        frontend = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v1.7.1/codedown-frontend-1.7.1.tar.gz";
          hash = "sha256-OSKfmKJPVSa9Lis1314ms7HXd3ba+q6zvbTX9DygCnU=";
          stripRoot = false;
        };

        wrappedServer = with pkgs; runCommand "codedown-server-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper "${server}/${serverTarballs.${system}.binaryPath}" "$out/bin/codedown-server" \
            --prefix PATH : ${lib.makeBinPath [ nodejs nixCustom tmux rclone pkgsStatic.busybox bubblewrap slirp4netns screenshotter ]}
        '';

        config = pkgs.callPackage ./config.nix { inherit frontend templates nixCustom; };

        runnerScript = with pkgs; writeShellScript "codedown-server.sh" ''
          CONFIG_DIR=''${XDG_CONFIG_HOME:-$HOME/.config}/codedown

          if [ ! -d "$CONFIG_DIR" ]; then
            echo "Creating $CONFIG_DIR"
            mkdir -p "$CONFIG_DIR"
          fi

          CONFIG_FILE="$CONFIG_DIR/config.json"
          if [ ! -f "$CONFIG_FILE" ]; then
            echo "Installing initial configuration to $CONFIG_FILE"
            ${pkgs.gnused}/bin/sed "s|CODEDOWN_ROOT|$CONFIG_DIR|g" "${config}" > "$CONFIG_FILE"
          fi

          # Make directories used by server
          mkdir -p "$CONFIG_DIR/local_sandboxes"
          mkdir -p "$CONFIG_DIR/server_root"

          ${wrappedServer}/bin/codedown-server -c "$CONFIG_FILE" "$@"
        '';

      in
        {
          apps = {
            default = {
              type = "app";
              program = "${runnerScript}";
            };
          };

          packages = {
            inherit config runnerScript;
            server = wrappedServer;
            default = runnerScript;
          };
        });
}
