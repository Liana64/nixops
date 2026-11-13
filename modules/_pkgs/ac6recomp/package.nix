{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeDesktopItem,
  symlinkJoin,
  writeShellApplication,
  formats,
  bubblewrap,
  alsa-lib,
  dbus,
  glib,
  gtk3,
  libpulseaudio,
  libusb1,
  pipewire,
  systemdLibs,
  vulkan-loader,
  libx11,
  libxcb,
  zlib,
  closureInfo,
  roots ? [],
  games,
}: let
  pname = "ac6recomp";
  version = "1.0.0";

  config = (formats.toml {}).generate "ac6recomp.toml" {
    fullscreen = true;
    draw_resolution_scale_x = 2;
    draw_resolution_scale_y = 2;
    log_file = "ac6recomp.log";
  };

  unwrapped = stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;
    src = fetchurl {
      url = "https://github.com/termuxuser123/AC6_recomp/releases/download/v${version}/ac6recomp-linux-x86_64.tar.gz";
      hash = "sha256-Tf4S3cm+yU9N/kKRkAGpKvvDI4J5LFfUORt28DVQiFw=";
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [alsa-lib glib gtk3 libpulseaudio libusb1 pipewire stdenv.cc.cc.lib libx11 libxcb zlib];
    runtimeDependencies = map lib.getLib [dbus systemdLibs vulkan-loader];
    autoPatchelfIgnoreMissingDeps = ["libjack.so.0" "libsndio.so.7" "libsteam_api.so"];

    installPhase = ''
      install -Dm555 ac6recomp -t $out/libexec
      install -Dm444 gamecontrollerdb.txt -t $out/libexec
      install -Dm444 ${config} $out/libexec/ac6recomp.toml
    '';
  };

  launcher = writeShellApplication {
    name = pname;
    runtimeInputs = [bubblewrap];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}"
      dir="$data/ac6recomp"
      mkdir -p "$dir"
      shopt -s nullglob
      isos=(${lib.escapeShellArg games}/*.iso)
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
        --bind ${lib.escapeShellArg games} ${lib.escapeShellArg games} \
        --chdir "$dir" \
        --setenv HOME "$dir" \
        --setenv XDG_DATA_HOME "$data" \
        --setenv XDG_RUNTIME_DIR "$run" \
        --setenv PATH /var/empty \
        "''${env[@]}" \
        -- ${unwrapped}/libexec/ac6recomp "''${isos[0]:-$dir/assets}" --user_data_root ${lib.escapeShellArg games} "$@"
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
      description = "Static recompilation of Ace Combat 6, confined with bubblewrap";
      homepage = "https://github.com/termuxuser123/AC6_recomp";
      license = lib.licenses.bsd3;
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  }
