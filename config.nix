{ pkgs

, nixCustom

, rootDir ? "CODEDOWN_ROOT"
, optionOverrides ? {}

, frontend
, templates
}:

let
  runnerBinDir = pkgs.buildEnv {
    name = "codedown-runner-bin-dir";
    paths = with pkgs; [bashInteractive busybox tmux nixCustom fuse cacert nix-prefetch-git];
  };
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
