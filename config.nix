{ lib
, pkgs
, pkgsStatic
, runCommand
, stdenv
, tmux

, nixCustom

, rootDir ? "CODEDOWN_ROOT"
, optionOverrides ? {}

, frontend
, templates
}:

let
  runnerBinDir = runCommand "runner-bin" {} (''
    mkdir -p $out/bin
    cp ${pkgsStatic.bashInteractive}/bin/bash "$out/bin"

    # Linux systems should have a /bin/sh
    ln -s $out/bin/bash $out/bin/sh

    COREUTILS="${pkgsStatic.coreutils}"
    cp "$COREUTILS/bin/coreutils" $out/bin/
    find "$COREUTILS/bin" -type l | while read -r link; do
      ln -s "coreutils" "$out/bin/$(basename $link)"
    done

    cp ${pkgsStatic.findutils}/bin/find $out/bin
    cp ${pkgsStatic.findutils}/bin/xargs $out/bin

    cp ${pkgsStatic.which}/bin/which $out/bin

    cp ${pkgsStatic.gnugrep}/bin/grep $out/bin
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    cp ${pkgsStatic.tmux}/bin/tmux "$out/bin"
    cp ${pkgsStatic.fuse}/bin/fusermount $out/bin
    cp ${pkgsStatic.slirp4netns}/bin/slirp4netns $out/bin
  '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
    cp ${tmux.override { ncurses = pkgsStatic.ncurses; }}/bin/tmux "$out/bin"
  '');

in

pkgs.writeTextFile {
  name = "codedown-config.json";
  text = pkgs.callPackage ./config-content.nix {
    inherit rootDir optionOverrides;
    inherit frontend templates;

    bootstrapNixpkgs = pkgs.path;
    nixBinDir = "${nixCustom}/bin";
    certBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    termInfo = "${pkgs.ncurses}/share/terminfo";
    runnerBinDir = "${runnerBinDir}/bin";
  };
}
