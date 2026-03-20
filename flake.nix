{
  description = "CodeDown Desktop";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      version = "1.8.1"; # version
      forAllSystems = nixpkgs.lib.genAttrs systems;

      urlFor = {
        x86_64-linux = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-${version}-linux-amd64-unpacked.tar.gz"; # tarball-url-amd64
        aarch64-linux = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-${version}-linux-arm64-unpacked.tar.gz"; # tarball-url-arm64
      };
      hashFor = {
        x86_64-linux = "sha256-DWfU0gI9Sv5sDsYw3bmmVRN4eyP3+7flEZ9wFROVurg="; # tarball-hash-amd64
        aarch64-linux = "sha256-UYk5P/vX6I7Y2b45m4OEb0x+SQK7exk6FNZu8Tve7BU="; # tarball-hash-arm64
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

          nativeBuildInputs = with pkgs; [ autoPatchelfHook ];

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
          # ELF binaries, static binaries, and shebangs that must not be touched.
          # Disable the entire fixup phase and handle autoPatchelf manually.
          dontFixup = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/codedown
            cp -r . $out/lib/codedown/

            # Patch only the top-level Electron binaries/libs, not the bundled
            # resources dir (which contains static binaries and a store template).
            autoPatchelf --no-recurse $out/lib/codedown

            # Remove chrome-sandbox so Electron falls back to the user namespace
            # sandbox instead of aborting over the SUID bit (which can't be set
            # in the nix store).
            rm -f $out/lib/codedown/chrome-sandbox

            install -Dm755 ${./wrapper.sh} $out/bin/codedown
            patchShebangs $out/bin/codedown
            substituteInPlace $out/bin/codedown --replace-fail "@out@" "$out"

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
