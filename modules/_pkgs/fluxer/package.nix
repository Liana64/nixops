{
  lib,
  appimageTools,
  fetchurl,
}: let
  pname = "fluxer";
  version = "2026.1108.50402";
  src = fetchurl {
    url = "https://pkgs.fluxer.com/desktop/stable/linux/x64/${version}/appimage";
    name = "fluxer-${version}.AppImage";
    hash = "sha256-01Z6VWvA0IOdpiWODpHUkcDRuoSNKek7h7eWyDi2JUM=";
  };
  contents = appimageTools.extractType2 {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;
    extraInstallCommands = ''
      install -Dm444 ${contents}/app.fluxer.FluxerDesktop.desktop -t $out/share/applications
      install -Dm444 ${contents}/fluxer.png -t $out/share/icons/hicolor/512x512/apps
      substituteInPlace $out/share/applications/app.fluxer.FluxerDesktop.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=fluxer' \
        --replace-fail '"/opt/Fluxer/fluxer"' 'fluxer'
    '';
    meta = {
      description = "Fluxer instant messaging and VoIP client";
      homepage = "https://fluxer.com";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      mainProgram = "fluxer";
    };
  }
