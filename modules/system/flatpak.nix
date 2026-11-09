# @desc: Flatpak app set — converged by the daily flatpak-repo timer or `just flatpaks`, never at switch
{user, ...}: {
  flake.modules.homeManager.flatpak = {lib, ...}: let
    overrides = {
      "com.rustdesk.RustDesk".Context.filesystems = "!home;xdg-download";
      "org.gnome.Calculator".Context.sockets = "!fallback-x11;!x11";
      "org.gnome.Calendar".Context.sockets = "!fallback-x11;!x11";
      "org.gnome.Snapshot".Context.sockets = "!fallback-x11;!x11";
      "org.pulseaudio.pavucontrol" = {
        Context.sockets = "!fallback-x11;!x11";
        Environment."PULSE_PROP_media.category" = "";
      };
    };
  in {
    xdg.dataFile = lib.mapAttrs' (app: sections:
      lib.nameValuePair "flatpak/overrides/${app}" {
        text = lib.generators.toINI {} sections;
      })
    overrides;
  };

  flake.modules.nixos.flatpak = {
    pkgs,
    hardening,
    ...
  }: {
    # flatpaks are pretty good at sandboxing, so we ought to use them when available
    services.flatpak = {
      enable = true;
    };

    systemd.services.flatpak-repo = {
      after = ["network-online.target" "nss-lookup.target"];
      wants = ["network-online.target" "nss-lookup.target"];
      path = [pkgs.flatpak pkgs.gawk];
      script = ''
        flatpak override --socket=wayland
        flatpak override --nosocket=x11
        flatpak override --env=ELECTRON_OZONE_PLATFORM_HINT=wayland
        flatpak override --filesystem=xdg-config/gtk-3.0:ro
        flatpak override --filesystem=xdg-config/gtk-4.0:ro
        flatpak override --filesystem=/nix/store:ro

        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

        verified=(
          org.gnome.Calculator
          org.gnome.Showtime
          org.gnome.Loupe
          org.gnome.Maps
          org.gnome.TextEditor
          org.gnome.Snapshot
          org.gnome.Characters
          org.gnome.Calendar
          dev.bragefuglseth.Fretboard
          org.localsend.localsend_app
          org.pulseaudio.pavucontrol
          com.rustdesk.RustDesk
          com.github.tchx84.Flatseal
          # com.prusa3d.PrusaSlicer
          # com.github.johnfactotum.Foliate
          # org.freecad.FreeCAD
          # org.telegram.desktop
          # org.zulip.Zulip
        )

        unverified=(
          me.proton.Mail
        )

        desired=( "''${verified[@]}" "''${unverified[@]}" )

        installed=$(flatpak list --app --columns=application,origin | awk '$2 == "flathub" { print $1 }')
        for app in $installed; do
          keep=0
          for d in "''${desired[@]}"; do
            if [ "$app" = "$d" ]; then keep=1; break; fi
          done
          if [ "$keep" -eq 0 ]; then
            flatpak uninstall -y --noninteractive "$app" || true
          fi
        done

        flatpak install -y --noninteractive --or-update flathub "''${desired[@]}"
        flatpak update -y --noninteractive || true
        flatpak uninstall -y --noninteractive --unused || true
      '';
      unitConfig = {
        StartLimitIntervalSec = 3600;
        StartLimitBurst = 10;
      };
      serviceConfig =
        hardening.base
        // {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = 120;
        };
    };

    systemd.timers.flatpak-repo = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
    };

    systemd.user.extraConfig = ''
      DefaultEnvironment="PATH=/etc/profiles/per-user/${user.name}/bin:/run/current-system/sw/bin"
    '';
  };
}
