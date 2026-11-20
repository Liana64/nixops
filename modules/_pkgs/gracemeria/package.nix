{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeDesktopItem,
  symlinkJoin,
  writeShellApplication,
  bubblewrap,
  alsa-lib,
  dbus,
  libglvnd,
  libpulseaudio,
  libusb1,
  pipewire,
  systemdLibs,
  vulkan-loader,
  libx11,
  libxcursor,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxscrnsaver,
  closureInfo,
  roots ? [],
  games,
}: let
  pname = "gracemeria";
  version = "1.0.0";
  exe = "AceCombat6";

  unwrapped = stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;
    src = fetchurl {
      url = "https://github.com/Dipshet/GracemeriaRecomp/releases/download/v${version}/GracemeriaRecomp-${version}-linux-x64.tar.gz";
      hash = "sha256-uMqjF4riky6mUKAF/ZCcFgbL3Cf3RcnAzYJy4+VhprQ=";
    };
    sourceRoot = ".";

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = map lib.getLib [
      stdenv.cc.cc
      alsa-lib
      dbus
      libglvnd
      libpulseaudio
      libusb1
      pipewire
      systemdLibs
      vulkan-loader
      libx11
      libxcursor
      libxext
      libxfixes
      libxi
      libxrandr
      libxscrnsaver
    ];
    autoPatchelfIgnoreMissingDeps = [
      "libdrm.so.2"
      "libfribidi.so.0"
      "libGLES_CM.so.1"
      "libjack.so.0"
      "libsteam_api.so"
      "libthai.so.0"
      "libXtst.so.6"
    ];

    installPhase = ''
      install -Dm555 ${exe} -t $out/libexec
    '';
  };

  launcher = writeShellApplication {
    name = pname;
    runtimeInputs = [bubblewrap];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}"
      dir="$data/${pname}"
      games=${lib.escapeShellArg games}
      mkdir -p "$dir" "$games/saves"
      shopt -s nullglob
      isos=("$games"/*.iso)
      run="''${XDG_RUNTIME_DIR:?}"
      env=()
      for v in DISPLAY XAUTHORITY LANG "''${!SDL_@}"; do
        [ -n "''${!v:-}" ] && env+=(--setenv "$v" "''${!v}")
      done
      store=()
      while read -r p; do store+=(--ro-bind "$p" "$p"); done < ${closureInfo {rootPaths = [unwrapped] ++ roots;}}/store-paths
      exec bwrap \
        --unshare-all \
        --die-with-parent \
        --new-session \
        --clearenv \
        "''${store[@]}" \
        --ro-bind /run/opengl-driver /run/opengl-driver \
        --ro-bind /run/udev /run/udev \
        --ro-bind /sys/bus /sys/bus \
        --ro-bind /sys/class /sys/class \
        --ro-bind /sys/dev /sys/dev \
        --ro-bind /sys/devices /sys/devices \
        --ro-bind-try /etc/fonts /etc/fonts \
        --proc /proc \
        --dev /dev \
        --dev-bind /dev/dri /dev/dri \
        --dev-bind /dev/input /dev/input \
        --tmpfs /tmp \
        --ro-bind-try /tmp/.X11-unix /tmp/.X11-unix \
        --ro-bind-try "$run/pulse" "$run/pulse" \
        ''${XAUTHORITY:+--ro-bind "$XAUTHORITY" "$XAUTHORITY"} \
        --bind "$dir" "$dir" \
        --ro-bind ${unwrapped}/libexec/${exe} "$dir/${exe}" \
        --bind "$games" "$games" \
        --chdir "$dir" \
        --setenv HOME "$dir" \
        --setenv XDG_DATA_HOME "$data" \
        --setenv XDG_RUNTIME_DIR "$run" \
        --setenv PATH /var/empty \
        --setenv AC6_CHECK_UPDATES 0 \
        --setenv AC6_SAVE_DIR "$games/saves" \
        ''${isos[0]:+--setenv AC6_ISO "''${isos[0]}"} \
        "''${env[@]}" \
        -- "$dir/${exe}" "$@"
    '';
  };
in
  symlinkJoin {
    name = "${pname}-${version}";
    paths = [
      launcher
      (makeDesktopItem {
        name = pname;
        desktopName = "Ace Combat 6";
        exec = pname;
        categories = ["Game"];
      })
    ];

    meta = {
      description = "GracemeriaRecomp, a static recompilation of Ace Combat 6, confined with bubblewrap";
      homepage = "https://github.com/Dipshet/GracemeriaRecomp";
      license = lib.licenses.gpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  }
