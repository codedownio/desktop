{ fetchurl
, runCommand
}:

{
  packageBinary = { name, url, sha256 }: let
    binary = fetchurl { inherit url sha256; };
  in
    runCommand name {} ''
      mkdir -p $out/bin
      install --mode=0555 ${binary} $out/bin/${name}
    '';
}
