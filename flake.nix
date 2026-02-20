{
  description = "CodeDown Desktop";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";

  inputs.templates.url = "github:codedownio/templates";
  inputs.templates.flake = false;

  outputs = { self, flake-utils, nixpkgs, templates }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        version = "1.7.3"; # version

        pkgs = import nixpkgs { inherit system; };

        nixTarballs = {
          x86_64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v${version}/nix-static-2.32.4-x86_64-linux.tar.gz"; # nix-tarball-x86_64-url
            hash = "sha256-2cCIQEsvcUcojhPzy731GnpDVTwWrxfa75KvxLLeOk8="; # nix-tarball-x86_64-hash
          };
          aarch64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v${version}/nix-static-2.32.4-aarch64-linux.tar.gz"; # nix-tarball-aarch64-url
            hash = "sha256-DFje+EYeYMlx5IKCAnspHjLikuhjFzYljSo6Ac1W9SI="; # nix-tarball-aarch64-hash
          };
        };

        serverTarballs = {
          x86_64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-server-${version}-x86_64-linux.tar.gz"; # server-tarball-x86_64-url
            hash = "sha256-IVR19n5i8EmIXTHaF6o+1psH8N/AeT8nAHZjcccbtXw="; # server-tarball-x86_64-hash
            stripRoot = true;
            binaryPath = "codedown-server";
          };
          aarch64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-server-${version}-aarch64-linux.tar.gz"; # server-tarball-aarch64-url
            hash = "sha256-OksIm/IpVajLLeAExw1R8/jrbLol/RfQMhZhuG1NLbY="; # server-tarball-aarch64-hash
            stripRoot = false;
            binaryPath = "bin/codedown-server";
          };
        };

        screenshotterTarballs = {
          x86_64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-screenshotter-0.1.1-x86_64-linux.tar.gz"; # screenshotter-tarball-x86_64-url
            hash = "sha256-MJrYoEjcW5pAsiUV5Zmq6K8M4hZK5t3ETkYHCmvl/w0="; # screenshotter-tarball-x86_64-hash
          };
          aarch64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-screenshotter-0.1.1-aarch64-linux.tar.gz"; # screenshotter-tarball-aarch64-url
            hash = "sha256-j/IspnxxnzWBKj4nkg4NU1tqKQ5JMo47IqVdEPWLBbM="; # screenshotter-tarball-aarch64-hash
          };
        };

        runnerBinDirTarballs = {
          x86_64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v${version}/runner-bin-dir-${version}-x86_64-linux.tar.gz"; # runner-bin-dir-x86_64-url
            hash = "sha256-oP0KhsNq/5wA0lP4BKv4eFVldhiV/Rj5At5IKP362YQ="; # runner-bin-dir-x86_64-hash
          };
          aarch64-linux = {
            url = "https://github.com/codedownio/desktop/releases/download/v${version}/runner-bin-dir-${version}-aarch64-linux.tar.gz"; # runner-bin-dir-aarch64-url
            hash = "sha256-XrbzYMdI+aOYelJXX7fdxsGPY5t4FGTqOjZ42NPD3ls="; # runner-bin-dir-aarch64-hash
          };
        };

        nixCustom = pkgs.fetchzip {
          url = nixTarballs.${system}.url;
          hash = nixTarballs.${system}.hash;
          stripRoot = false;
        };

        server = pkgs.fetchzip {
          url = serverTarballs.${system}.url;
          hash = serverTarballs.${system}.hash;
          stripRoot = serverTarballs.${system}.stripRoot;
        };

        screenshotter = let
          screenshotterUnpacked = pkgs.fetchzip {
            url = screenshotterTarballs.${system}.url;
            hash = screenshotterTarballs.${system}.hash;
            stripRoot = false;
          };
        in with pkgs; runCommand "codedown-screenshotter-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper ${screenshotterUnpacked}/bin/codedown-screenshotter "$out/bin/codedown-screenshotter" \
            --add-flags "--chrome-path ${pkgs.chromium}/bin/chromium"
        '';

        frontend = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-frontend-${version}.tar.gz"; # frontend-url
          hash = "sha256-WsKT7LOb9wpd9R1H24vfbdX06jQDfXjx8wiB2tiZdl4="; # frontend-hash
          stripRoot = false;
        };

        runnerBinDir = pkgs.fetchzip {
          url = runnerBinDirTarballs.${system}.url;
          hash = runnerBinDirTarballs.${system}.hash;
          stripRoot = false;
        };

        wrappedServer = with pkgs; runCommand "codedown-server-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper "${server}/${serverTarballs.${system}.binaryPath}" "$out/bin/codedown-server" \
            --prefix PATH : ${lib.makeBinPath [ nodejs nixCustom tmux rclone pkgsStatic.busybox bubblewrap slirp4netns screenshotter ]}
        '';

        config = pkgs.callPackage ./config.nix { inherit frontend templates nixCustom runnerBinDir; };

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
          inherit version;

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
