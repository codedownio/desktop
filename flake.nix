{
  description = "CodeDown Desktop";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      version = "1.8.0"; # version
      forAllSystems = nixpkgs.lib.genAttrs systems;

      urlFor = {
        x86_64-linux = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-${version}-linux-amd64-unpacked.tar.gz"; # tarball-url-amd64
        aarch64-linux = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-${version}-linux-arm64-unpacked.tar.gz"; # tarball-url-arm64
      };
      hashFor = {
        x86_64-linux = "sha256-wyuhr/jvzo6U5eqb3D+Lo08gVK3qyKYfQVkRmTvLlZI="; # tarball-hash-amd64
        aarch64-linux = "sha256-vrityZLIg8rUTKFwqlMbQDt6shxfybDbuFCzsultM7w="; # tarball-hash-arm64
      };

      mkCodedown = system:
        let pkgs = import nixpkgs { inherit system; };
        in pkgs.stdenv.mkDerivation {
          pname = "codedown";
          inherit version;

          src = pkgs.fetchzip {
            url = urlFor.${system};
            hash = hashFor.${system};
          };

          nativeBuildInputs = with pkgs; [ autoPatchelfHook makeWrapper ];

          buildInputs = with pkgs; [
            alsa-lib
            at-spi2-atk
            cairo
            cups
            dbus
            expat
            gdk-pixbuf
            glib
            gtk3
            libdrm
            libxkbcommon
            mesa
            nspr
            nss
            pango
            xorg.libX11
            xorg.libXcomposite
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXrandr
            xorg.libxcb
          ];

          # The resources dir contains a bundled nix store template with its own
          # ELF binaries and symlinks pointing to store paths that don't exist on
          # the build machine. Exclude it from autoPatchelf and broken-symlink checks.
          autoPatchelfIgnorePaths = [ "lib/codedown/resources" ];
          dontCheckForBrokenSymlinks = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/codedown
            cp -r . $out/lib/codedown/

            # Remove chrome-sandbox so Electron falls back to the user namespace
            # sandbox instead of aborting over the SUID bit (which can't be set
            # in the nix store).
            rm -f $out/lib/codedown/chrome-sandbox

            mkdir -p $out/bin
            makeWrapper $out/lib/codedown/codedown $out/bin/codedown

            runHook postInstall
          '';

          meta = {
            description = "CodeDown Desktop";
            mainProgram = "codedown";
            platforms = [ system ];
          };
        };
    in {
      inherit version;

      packages = forAllSystems (system: {
        default = mkCodedown system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/codedown";
        };
      });
    };
}
