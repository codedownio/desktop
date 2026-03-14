{
  description = "CodeDown Desktop";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      version = "1.8.0"; # version
    in {
      inherit version;

      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "codedown";
        inherit version;

        src = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v${version}/codedown-${version}-linux-x64-unpacked.tar.gz"; # tarball-url
          hash = "sha256-wyuhr/jvzo6U5eqb3D+Lo08gVK3qyKYfQVkRmTvLlZI="; # tarball-hash
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

        installPhase = ''
          runHook preInstall

          mkdir -p $out/lib/codedown
          cp -r . $out/lib/codedown/

          mkdir -p $out/bin
          makeWrapper $out/lib/codedown/codedown $out/bin/codedown

          runHook postInstall
        '';

        meta = {
          description = "CodeDown Desktop";
          mainProgram = "codedown";
          platforms = [ "x86_64-linux" ];
        };
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/codedown";
      };
    };
}
