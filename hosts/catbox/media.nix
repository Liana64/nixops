{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  inherit (inputs.self.network) home clients;
  tv = pkgs.writeShellScriptBin "tv" ''
    exec ${pkgs.curl}/bin/curl -fsS -m 5 --retry 15 --retry-delay 1 --retry-all-errors -X POST "http://${inputs.self.network.home.hosts.tv}:8060/$1"
  '';
  tile = name: icon: exec:
    pkgs.makeDesktopItem {
      inherit name icon exec;
      desktopName = name;
    };
  webapp = name: icon: url: tile name icon "plasma-bigscreen-webapp --name ${name} ${url}";
  steamosctl = "${pkgs.jovianPackages.steamos-manager}/bin/steamosctl";
  sessionToggle = pkgs.writeShellScript "session-toggle" ''
    if ${pkgs.systemd}/bin/systemctl --user -q is-active gamescope-session.service
    then exec ${steamosctl} switch-to-desktop-mode
    else exec ${steamosctl} switch-to-game-mode
    fi
  '';
  shortcut = name: "${pkgs.systemd}/bin/busctl --user call org.kde.kglobalaccel /component/plasmashell org.kde.kglobalaccel.Component invokeShortcut s '${name}'";
  flircKeys = pkgs.writeText "flirc-keys.conf" ''
    KEY_PROG1 1 ${sessionToggle}
    KEY_PROG2 1 ${shortcut "Toggle Bigscreen Home Overlay"}
    KEY_PROG3 1 ${shortcut "Toggle Bigscreen Settings"}
  '';
  flirc = ''ATTRS{idVendor}=="20a0", ATTRS{idProduct}=="0006"'';
  icons = {
    roku = pkgs.runCommand "roku.svg" {} ''
      sed 's/<svg /<svg fill="#6F1AB1" /' ${pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/simple-icons/simple-icons/c8a98c7099c33a8ef8461dd97263235f348e7077/icons/roku.svg";
        hash = "sha256-PtffGMdO0+8f8lxaYQ4GjSjJN+14fFPMjMFE5zX1eU0=";
      }} > $out
    '';
    youtube = pkgs.runCommand "youtube.svg" {} "cp ${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/youtube.svg $out";
  };
in {
  jovian.steam.desktopSession = "plasma-bigscreen-wayland";
  nixpkgs.overlays = [
    (_: prev: {
      kdePackages = prev.kdePackages.overrideScope (_: p: {
        plasma-bigscreen = p.plasma-bigscreen.overrideAttrs (o: {
          buildInputs = lib.remove prev.libcec o.buildInputs;
          patches = (o.patches or []) ++ [../../patches/0004-plasma-bigscreen-misc-row.patch ../../patches/0005-plasma-bigscreen-ignore-steam.patch ../../patches/0006-plasma-bigscreen-remove-search.patch];
          postPatch =
            (o.postPatch or "")
            + ''
              substituteInPlace containments/homescreen/package/contents/ui/launcher/LauncherHome.qml \
                --replace-fail @misc@ '${builtins.toJSON ["steam.desktop" "systemsettings.desktop" "org.kde.kdeconnect.app.desktop" "syncthing-ui.desktop" "thunar.desktop"]}' \
                --replace-fail 'visible: Plasmoid.configuration.showRecent && count > 0' 'visible: false'
            '';
        });
      });
      jellyfin-desktop = prev.jellyfin-desktop.overrideAttrs (o: {
        cmakeFlags = (o.cmakeFlags or []) ++ ["-DENABLE_CEC=OFF"];
      });
    })
  ];
  programs.kde-pim.enable = false;

  services = {
    desktopManager.plasma6.enable = true;
    displayManager = {
      sessionPackages = [pkgs.kdePackages.plasma-bigscreen];
      defaultSession = lib.mkForce config.jovian.steam.desktopSession;
    };
    udev = {
      packages = [
        (pkgs.writeTextDir "lib/udev/rules.d/70-flirc.rules" ''
          ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ${flirc}, ATTR{power/wakeup}="enabled", ATTR{../power/wakeup}="enabled"
          SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", ${flirc}, SYMLINK+="input/flirc", TAG+="uaccess", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="flirc-keys.service"
        '')
      ];
      extraHwdb = ''
        evdev:input:b0003v20A0p0006*
         KEYBOARD_KEY_7004a=homepage
         KEYBOARD_KEY_70041=sleep
         KEYBOARD_KEY_70042=prog1
         KEYBOARD_KEY_70043=prog2
         KEYBOARD_KEY_70044=prog3
      '';
    };
    sunshine.settings.global_prep_cmd = builtins.toJSON [
      {
        do = "${pkgs.writeShellScript "tv-off" "${tv}/bin/tv keypress/PowerOff || true"}";
        undo = "";
      }
    ];
  };

  systemd = {
    user.services.tv-output = {
      description = "Scale the TV and mirror the Sunshine output onto it";
      wantedBy = ["plasma-workspace.target"];
      after = ["plasma-kwin_wayland.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.scale.2 output.HDMI-A-1.mirror.DP-3";
      };
    };
    user.services.kdeconnectd = {
      description = "KDE Connect in the Steam session";
      wantedBy = ["gamescope-session.service"];
      partOf = ["gamescope-session.service"];
      serviceConfig.ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnectd";
    };
    user.services.flirc-keys = {
      description = "Flirc remote actions";
      bindsTo = ["dev-input-flirc.device"];
      after = ["dev-input-flirc.device"];
      unitConfig.ConditionUser = "home";
      serviceConfig = {
        ExecStart = "${pkgs.triggerhappy}/bin/thd --triggers ${flircKeys} --deviceglob /dev/input/flirc";
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = "AF_UNIX";
        SystemCallArchitectures = "native";
      };
    };
    user.services.gamescope-session.serviceConfig.ExecStartPre = "-${pkgs.systemd}/bin/systemctl --user stop app-org.kde.plasma.bigscreen.inputhandler@*.service";
    tmpfiles.rules = [
      "D /home/home/.local/share/applications 0555 home users -"
      "L+ /usr/share/wallpapers - - - - /run/current-system/sw/share/wallpapers"
    ];
    user.services.tv-input = {
      description = "Wake the TV and switch it to catbox";
      wantedBy = ["cecd.service"];
      after = ["cecd.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/busctl --user call com.steampowered.CecDaemon1 /com/steampowered/CecDaemon1/Daemon com.steampowered.CecDaemon1.Daemon1 Wake";
      };
    };
  };

  networking.firewall.extraInputRules = ''
    ip saddr { ${lib.concatStringsSep ", " ([home.subnet] ++ clients.${user.name})} } meta l4proto { tcp, udp } th dport 1714-1764 accept
  '';

  environment = {
    etc."cecd/config.toml".source = (pkgs.formats.toml {}).generate "cecd.toml" {
      osd_name = "catbox";
      wake_tv = true;
      suspend_tv = true;
    };
    plasma6.excludePackages = with pkgs.kdePackages; [ark discover dolphin dolphin-plugins elisa gwenview khelpcenter konsole okular qrca spectacle];
    etc."xdg/applications-blacklistrc".text = lib.generators.toINI {} {
      # plasma-bigscreen will overwrite this blacklist unless we make it immutable
      Applications."blacklist[$i]" = lib.concatStringsSep "," [
        "com.vysp3r.ProtonPlus"
        "cups"
        "dev.lizardbyte.app.Sunshine"
        "kdesystemsettings"
        "LocalSend"
        "net.retrodeck.retrodeck.Configurator"
        "nixos-manual"
        "org.jellyfin.JellyfinDesktop"
        "org.kde.drkonqi.coredump.gui"
        "org.kde.kdeconnect.nonplasma"
        "org.kde.kdeconnect.sms"
        "org.kde.kate"
        "org.kde.kinfocenter"
        "org.kde.kmenuedit"
        "org.kde.kwalletmanager"
        "org.kde.kwrite"
        "org.kde.plasma.bigscreen.inputhandler"
        "org.kde.plasma-systemmonitor"
        "org.kde.plasma.bigscreen.uvcviewer"
        "org.kde.plasma.emojier"
        "PCSX2"
        "plasma-bigscreen-swap-session"
        "protontricks"
        "thunar-bulk-rename"
        "thunar-settings"
      ];
    };
    etc."xdg/kwinrc".text = lib.generators.toINI {} {
      Wayland."InputMethod[$i]" = "/run/current-system/sw/share/applications/org.kde.plasma.keyboard.desktop";
    };
    etc."xdg/kdeglobals".text = lib.generators.toINI {} {
      General = {
        "font[$i]" = "Noto Sans,16";
        "menuFont[$i]" = "Noto Sans,16";
        "toolBarFont[$i]" = "Noto Sans,14";
        "smallestReadableFont[$i]" = "Noto Sans,12";
      };
      WM."activeFont[$i]" = "Noto Sans,16";
    };
    systemPackages = [
      tv
      pkgs.kdePackages.plasma-bigscreen
      pkgs.kdePackages.kdeconnect-kde
      pkgs.jellyfin-desktop
      (pkgs.makeDesktopItem {
        name = "Jellyfin";
        desktopName = "Jellyfin";
        icon = "org.jellyfin.JellyfinDesktop";
        exec = "env SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT=0x0000/0x0000 ${lib.getExe pkgs.jellyfin-desktop} --fullscreen --tv";
      })
      (webapp "YouTube" icons.youtube "--agent \"Mozilla/5.0 (Linux; Android 12) Cobalt/22.2.3-gold (PS4)\" https://www.youtube.com/tv")
      (tile "Roku" icons.roku "tv keypress/Home")
      (tile "SteamOS" "steam" "${pkgs.jovianPackages.steamos-manager}/bin/steamosctl switch-to-game-mode")
    ];
  };
}
