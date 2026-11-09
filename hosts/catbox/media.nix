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
          patches = (o.patches or []) ++ [../../patches/0004-plasma-bigscreen-misc-row.patch ../../patches/0005-plasma-bigscreen-ignore-steam.patch ../../patches/0006-plasma-bigscreen-remove-search.patch];
          postPatch =
            (o.postPatch or "")
            + ''
              substituteInPlace containments/homescreen/package/contents/ui/launcher/LauncherHome.qml \
                --replace-fail @misc@ '${builtins.toJSON ["steam.desktop" "systemsettings.desktop" "org.kde.kdeconnect.app.desktop"]}'
            '';
        });
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
    user.services.gamescope-session.serviceConfig.ExecStartPre = "-${pkgs.systemd}/bin/systemctl --user stop app-org.kde.plasma.bigscreen.inputhandler@*.service";
    tmpfiles.rules = [
      "D /home/home/.local/share/applications 0555 home users -"
      "L+ /usr/share/wallpapers - - - - /run/current-system/sw/share/wallpapers"
    ];
    services.tv-input = {
      description = "Wake the TV and switch it to catbox";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ["-${tv}/bin/tv keypress/PowerOn" "${tv}/bin/tv launch/tvinput.hdmi1"];
      };
    };
  };

  networking.firewall.extraInputRules = ''
    ip saddr { ${lib.concatStringsSep ", " ([home.subnet] ++ clients.${user.name})} } meta l4proto { tcp, udp } th dport 1714-1764 accept
  '';

  powerManagement.resumeCommands = "${tv}/bin/tv keypress/PowerOn; ${tv}/bin/tv launch/tvinput.hdmi1";

  environment = {
    plasma6.excludePackages = with pkgs.kdePackages; [ark discover dolphin dolphin-plugins elisa gwenview kate khelpcenter konsole okular qrca spectacle];
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
        "org.kde.kinfocenter"
        "org.kde.kmenuedit"
        "org.kde.kwalletmanager"
        "org.kde.plasma.bigscreen.inputhandler"
        "org.kde.plasma-systemmonitor"
        "org.kde.plasma.bigscreen.uvcviewer"
        "org.kde.plasma.emojier"
        "PCSX2"
        "plasma-bigscreen-swap-session"
        "protontricks"
        "thunar"
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
