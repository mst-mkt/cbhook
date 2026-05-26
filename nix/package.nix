{
  lib,
  stdenv,
  moonPlatform,
  makeWrapper,
  wl-clipboard,
  xclip,
  coreutils,
  moon-registry,
}:
let
  src = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: _type:
      !(builtins.elem (baseNameOf path) [
        "_build"
        ".mooncakes"
        ".direnv"
        "result"
        "target"
        ".claude"
      ]);
  };
  moonModJson = ../moon.mod.json;
  runtimeBins = lib.optionals stdenv.hostPlatform.isLinux [
    wl-clipboard
    xclip
    coreutils
  ];
  unwrapped = moonPlatform.buildMoonPackage {
    inherit src moonModJson;
    moonRegistryIndex = moon-registry;
    doCheck = false;
    meta = {
      description = "Watch the clipboard and transform it with hooks";
      mainProgram = "cbhook";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  };
in
if runtimeBins == [ ] then
  unwrapped
else
  unwrapped.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeWrapper ];
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/cbhook \
        --inherit-argv0 \
        --prefix PATH : ${lib.makeBinPath runtimeBins}
    '';
  })
