{
  description = "CodeDown Desktop";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:codedownio/nixpkgs/release-22.11";

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

      in rec {
        apps = {

        };

        packages = {
          default = pkgs.hello;
        };
      });
}
