{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
  at-spi2-atk,
  cups,
  gtk3,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libxkbcommon,
  nss,
  pipewire,
  systemdLibs,
  xorg,
}: let
  pname = "fluxer";
  version = "2026.1108.50402";
  appimage = fetchurl {
    url = "https://pkgs.fluxer.com/desktop/stable/linux/x64/${version}/appimage";
    name = "fluxer-${version}.AppImage";
    hash = "sha256-01Z6VWvA0IOdpiWODpHUkcDRuoSNKek7h7eWyDi2JUM=";
  };
in
  stdenv.mkDerivation {
    inherit pname version;
    src = appimageTools.extractType2 {
      inherit pname version;
      src = appimage;
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [alsa-lib at-spi2-atk cups gtk3 libgbm libxkbcommon nss pipewire xorg.libXcomposite xorg.libXdamage xorg.libXrandr];
    runtimeDependencies = map lib.getLib [libGL libnotify libpulseaudio systemdLibs];

    installPhase = ''
      mkdir -p $out/bin $out/share/applications
      cp -r . $out/lib
      rm -rf $out/lib/{usr,AppRun,chrome-sandbox,fluxer.png,.DirIcon,*.desktop}
      install -Dm444 usr/share/icons/hicolor/1024x1024/apps/fluxer.png -t $out/share/icons/hicolor/1024x1024/apps
      substitute app.fluxer.FluxerDesktop.desktop $out/share/applications/app.fluxer.FluxerDesktop.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=fluxer' \
        --replace-fail '"/opt/Fluxer/fluxer"' 'fluxer'
      ln -s $out/lib/fluxer $out/bin/fluxer
    '';

    meta = {
      description = "Fluxer instant messaging and VoIP client";
      homepage = "https://fluxer.com";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      mainProgram = "fluxer";
    };
  }
