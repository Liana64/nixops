{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  libsForQt5,
  makeWrapper,
  udev,
}: let
  env = python3.withPackages (ps:
    with ps; [
      pyqt5
      hidapi
      simpleeval
      keyboard
      certifi
    ]);
in
  stdenv.mkDerivation rec {
    pname = "vial-gui";
    version = "0.7.5";

    src = fetchFromGitHub {
      owner = "vial-kb";
      repo = "vial-gui";
      tag = "v${version}";
      hash = "sha256-TWcm+UgROpd5pX/EV0SMx52C9i9Ip9vT61OQhsTiRi8=";
    };

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      mkdir -p $out/share/vial $out/share/vial/shim/fbs_runtime/application_context
      cp -r src $out/share/vial/

      touch $out/share/vial/shim/fbs_runtime/__init__.py

      cat > $out/share/vial/shim/fbs_runtime/application_context/__init__.py <<'EOF'
      from functools import cached_property


      def is_frozen():
          return False
      EOF

      cat > $out/share/vial/shim/fbs_runtime/application_context/PyQt5.py <<'EOF'
      import json
      import os

      _project = os.environ["VIAL_PROJECT"]


      class ApplicationContext:
          def __init__(self):
              with open(os.path.join(_project, "src/build/settings/base.json")) as f:
                  self.build_settings = json.load(f)
              _ = self.app

          def get_resource(self, name):
              return os.path.join(_project, "src/main/resources/base", name)
      EOF

      makeWrapper ${env}/bin/python $out/bin/vial-gui \
        --add-flags $out/share/vial/src/main/python/main.py \
        --run 'cd "$HOME"' \
        --prefix LD_LIBRARY_PATH : "${lib.getLib udev}/lib" \
        --set VIAL_PROJECT $out/share/vial \
        --set-default QT_QPA_PLATFORM wayland \
        --set PYTHONPATH "$out/share/vial/shim:$out/share/vial/src/main/python" \
        --prefix QT_PLUGIN_PATH : "${lib.getBin libsForQt5.qtwayland}/${libsForQt5.qtbase.qtPluginPrefix}"
    '';

    meta = {
      description = "Vial keyboard configurator, built from source without fbs";
      homepage = "https://get.vial.today";
      license = lib.licenses.gpl2Plus;
      mainProgram = "vial-gui";
    };
  }
