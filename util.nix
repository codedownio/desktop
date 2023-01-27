{ fetchurl
, runCommand
}:

{
  packageBinary = { name, binary }:
    runCommand name {} ''
      mkdir -p $out/bin
      install --mode=0555 ${binary} $out/bin/${name}
    '';
}
