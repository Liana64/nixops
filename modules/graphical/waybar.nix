# @desc: Waybar status bar
{...}: {
  flake.modules.homeManager.waybar = {
    inputs,
    config,
    lib,
    pkgs,
    colors,
    osConfig,
    hardening,
    ...
  }: let
    intake = import ../_lib/house-intake.nix {inherit pkgs lib hardening config;};
    intakeArgs = lib.escapeShellArgs intake.houses;
    machineSecrets = osConfig.machineSecrets or true;
    statusModules =
      lib.optionals (intake.houses != []) ["custom/nix-housing" "custom/veles"]
      ++ ["custom/harness-status" "custom/usbguard"]
      ++ lib.optional machineSecrets "custom/syncthing"
      ++ ["custom/caffeine"]
      ++ lib.optional machineSecrets "custom/vpn";
    app = pkgs.symlinkJoin {
      name = "waybar-scripts";
      paths = with pkgs; [
        (writeShellScriptBin "waybar-usbguard" (builtins.readFile ../../modules/bin/waybar-usbguard))
        (writeShellScriptBin "waybar-vpn" (builtins.readFile ../../modules/bin/waybar-vpn))
        (writeShellScriptBin "waybar-syncthing" (builtins.readFile ../../modules/bin/waybar-syncthing))
        (writeShellScriptBin "waybar-caffeine" (builtins.readFile ../../modules/bin/waybar-caffeine))
        (writeShellScriptBin "waybar-harness-status" (builtins.readFile ../../modules/bin/waybar-harness-status))
        (writeShellScriptBin "waybar-nix-housing" (builtins.readFile ../../modules/bin/waybar-nix-housing))
        (writeShellScriptBin "waybar-veles" (builtins.readFile ../../modules/bin/waybar-veles))
        (writeShellScriptBin "waybar-countdown" (builtins.readFile ../../modules/bin/waybar-countdown))
        #(writeShellScriptBin "track-date" (builtins.readFile ../../modules/bin/track-date))
        (writeShellScriptBin "waybar-sysinfo" (builtins.readFile ../../modules/bin/waybar-sysinfo))
        (writeShellScriptBin "caffeinate-toggle" (builtins.readFile ../../modules/bin/caffeinate-toggle))
        (writeShellScriptBin "waybar-airplane" (builtins.readFile ../../modules/bin/waybar-airplane))
        (writeShellScriptBin "waybar-rebuild" (builtins.readFile ../../modules/bin/waybar-rebuild))
        (writeShellScriptBin "waybar-reboot" (builtins.readFile ../../modules/bin/waybar-reboot))
        usbguard
      ];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/waybar-usbguard      --prefix PATH : $out/bin:${pkgs.lib.makeBinPath (with pkgs; [dbus coreutils gnugrep])}
        wrapProgram $out/bin/waybar-vpn --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [curl jq systemd])} \
          --set SOCKS ${with inputs.self.network.vpn; "${hosts.socks}:${toString socksPort}"}
        wrapProgram $out/bin/waybar-syncthing    --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [curl jq gnused procps])}
        wrapProgram $out/bin/waybar-harness-status --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [jq coreutils gnused procps sway systemd])}
        wrapProgram $out/bin/waybar-nix-housing   --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [intake.intake jq inotify-tools coreutils gnused systemd])}
        wrapProgram $out/bin/waybar-veles         --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [(import ../_lib/veles.nix pkgs) git jq inotify-tools coreutils gnused systemd])}
        wrapProgram $out/bin/waybar-countdown     --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [jq coreutils])}
        #wrapProgram $out/bin/track-date           --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [coreutils systemd])}
        wrapProgram $out/bin/waybar-sysinfo       --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [coreutils gnused gawk procps jq])}
        wrapProgram $out/bin/waybar-rebuild       --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [coreutils gnused gnugrep jq])}
        wrapProgram $out/bin/waybar-reboot        --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [coreutils gnused gnugrep jq systemd])}
      '';
    };
    # Toggle BT via BlueZ HCI power, never rfkill: rfkill power-gates the MT7925
    # BT-USB function and it fails to re-enumerate on unblock (descriptor read -110).
    btToggle = pkgs.writeShellScript "bt-toggle" ''
      if ${pkgs.bluez}/bin/bluetoothctl show | grep -q 'Powered: yes'; then
        ${pkgs.bluez}/bin/bluetoothctl power off
      else
        ${pkgs.bluez}/bin/bluetoothctl power on
      fi
    '';
    # on-click children inherit the unit confinement, bwrap/GPU die there, spawn via the user manager
    launch = cmd: "systemd-run --user --quiet --collect ${hardening.args hardening.launch} -- ${cmd}";
  in {
    # ProtectHome=true would also mask /run/user: read-only keeps ~/.config and the
    # wayland socket reachable, %t stays writable for the caffeinate flag
    systemd.user.services.waybar.Service =
      hardening.confined
      // {
        ProtectHome = "read-only";
        # launcher sysinfo tooltip reads /proc stat+meminfo, the pid subset masks them
        ProcSubset = "all";
        ReadWritePaths = "%t";
        # privacy's pipewire client loads module-rt (sched_setscheduler), EPERM makes it fall back instead of SIGSYS
        SystemCallFilter = map (f:
          if f == "~@resources"
          then "~@resources:EPERM"
          else f)
        hardening.confined.SystemCallFilter;
      };

    programs.waybar = with colors; {
      enable = true;
      # pow_format fuses number and unit (2.5kb/s), patch in the SI space
      package = pkgs.waybar.overrideAttrs (old: {
        patches = (old.patches or []) ++ [../../patches/0002-waybar-space-between-value-and-SI-unit.patch];
      });
      systemd = {
        enable = true;
        targets = ["graphical-session.target"];
      };

      style = ''
        @define-color raised mix(${background}, ${white}, 0.08);
        @define-color alert  mix(${color0}, ${red}, 0.5);

        * {
          /* propo variant, patched icons get ink-hugging advances, specimen-measured |L-R| <= 1 */
          font-family: "JetBrainsMono Nerd Font Propo";
          font-size: 12px;
          min-height: 0;
        }

        window#waybar {
          background: ${background};
          color: ${foreground};
        }

        window#waybar.power {
          background: transparent;
        }

        window#waybar.power #mode {
          background: ${background};
          color: ${white};
          padding: 0 8px;
        }

        tooltip {
          background: ${background};
          border: 1px solid ${color0};
          border-radius: 8px;
        }

        tooltip label {
          color: ${foreground};
        }

        menu,
        menuitem {
          font-family: "Cantarell";
          font-size: 12px;
        }

        #custom-clock,
        #network,
        #battery,
        #bluetooth,
        #pulseaudio,
        #tray,
        #custom-launcher,
        #custom-vpn,
        #custom-usbguard,
        #custom-caffeine,
        #custom-syncthing,
        #custom-countdown,
        #custom-airplane,
        #custom-rebuild,
        #custom-reboot,
        #custom-nix-housing,
        #custom-veles,
        #custom-harness-status {
          color: ${white};
          margin: 2px 2px;
          padding: 1px 8px;
          transition: background-color 0.15s ease, color 0.15s ease;
        }

        #custom-launcher {
          font-size: 14px;
          margin: 0 2px 0 5px;
          padding: 1px 8px;
        }

        #custom-clock {
          font-size: 13px;
          background: ${gray};
          padding: 1px 12px;
        }

        #custom-airplane.active {
          background: ${orange};
          color: ${darker};
        }

        #custom-harness-status.running {
          color: ${comment};
        }

        #custom-rebuild.failed,
        #custom-reboot.needed,
        #systemd-failed-units.degraded,
        #custom-nix-housing.failed,
        #custom-veles.failed {
          color: ${red};
        }

        #custom-countdown.today {
          color: ${green};
        }

        #custom-countdown.past {
          color: ${comment};
        }

        #tray {
          background: @raised;
          margin-right: 5px;
        }

        #nixos,
        #privacy,
        #status,
        #hw {
          background: @raised;
          margin: 2px 6px;
          /* end slots, filled segments need the same air as inter-icon gaps */
          padding: 1px 8px;
        }

        /* hidden children collapse the pill to zero width, so padding lives on them */
        #nixos {
          padding: 0;
        }

        #nixos #custom-rebuild,
        #nixos #custom-reboot,
        #nixos #systemd-failed-units {
          margin: 0;
          padding: 1px 8px;
        }

        #status #custom-harness-status,
        #status #custom-nix-housing,
        #status #custom-veles,
        #status #custom-usbguard,
        #status #custom-syncthing,
        #status #custom-vpn,
        #status #custom-caffeine,
        #hw #network,
        #hw #battery,
        #hw #bluetooth,
        #hw #pulseaudio {
          margin: 0 2px;
          padding: 1px 6px;
        }

        /* the % right bearing is base-font metric, propo does not change it, right stays under left */
        #hw #battery {
          padding: 1px 5.5px 1px 8px;
        }

        #status #custom-harness-status:hover,
        #status #custom-nix-housing:hover,
        #status #custom-veles:hover,
        #status #custom-usbguard:hover,
        #status #custom-syncthing:hover,
        #status #custom-vpn:hover,
        #status #custom-caffeine:hover,
        #hw #network:hover,
        #hw #battery:hover,
        #hw #bluetooth:hover,
        #hw #pulseaudio:hover {
          background: ${gray};
        }

        #workspaces {
          margin: 2px 4px;
          padding: 0 2px;
        }

        #workspaces button {
          color: ${comment};
          min-width: 16px;
          padding: 1px 8px;
          margin: 0 1px;
          border: none;
          border-radius: 0;
          box-shadow: none;
        }

        #workspaces button:not(.empty) {
          color: ${foreground};
        }

        #workspaces button:hover,
        #network:hover,
        #battery:hover,
        #bluetooth:hover,
        #pulseaudio:hover,
        #custom-vpn:hover,
        #custom-usbguard:hover,
        #custom-syncthing:hover,
        #custom-launcher:hover {
          background: ${gray};
          color: ${white};
        }

        #workspaces button.focused {
          background: ${gray};
          color: ${white};
          font-weight: bold;
        }

        #workspaces button.urgent {
          background: @alert;
          color: ${white};
        }

        #network.ethernet,
        #bluetooth.on {
          background: ${tan};
          color: ${darker};
        }

        #pulseaudio.muted,
        #bluetooth.off,
        #bluetooth.disabled {
          color: ${comment};
        }

        #network.disconnected,
        #custom-syncthing.disconnected,
        #custom-vpn.untrusted,
        #battery.critical {
          background: @alert;
        }

        #battery.warning,
        #custom-usbguard.blocked,
        #custom-syncthing.error,
        #custom-vpn.ephemeral-down {
          background: ${orange};
          color: ${darker};
        }

        #custom-vpn.ephemeral {
          background: ${emerald};
          color: ${darker};
        }

        #battery.charging,
        #custom-vpn.connected,
        #bluetooth.connected {
          background: ${green};
          color: ${darker};
        }

        #status #custom-caffeine.active {
          background: ${yellow};
          color: ${darker};
        }
      '';

      settings = {
        power = {
          name = "power";
          height = 25;
          id = "power";
          ipc = true;
          position = "top";
          output = ["*"];
          modules-right = ["sway/mode"];
          "sway/mode".tooltip = false;
        };

        mainBar = {
          layer = "top";
          position = "top";
          output = ["*"];

          modules-left = ["custom/launcher" "sway/workspaces"];
          modules-center = ["custom/clock"];
          modules-right = ["group/nixos" "privacy" "custom/airplane" "group/status" "group/hw" "tray"];

          # groups stack vertically on a horizontal bar unless told otherwise
          "group/nixos" = {
            orientation = "horizontal";
            modules = ["custom/rebuild" "custom/reboot" "systemd-failed-units"];
          };

          "custom/reboot" = {
            exec = "${app}/bin/waybar-reboot";
            return-type = "json";
            interval = 30;
            signal = 14;
          };

          "systemd-failed-units".format = "󰀩 {nr_failed}";

          privacy.icon-size = 12;

          "group/status" = {
            orientation = "horizontal";
            modules = statusModules;
          };

          "group/hw" = {
            orientation = "horizontal";
            modules = ["network" "battery" "bluetooth" "pulseaudio"];
          };

          "custom/launcher" = {
            # nixos logo U+F313 is BMP-PUA, edit tools strip it, patch via sed only
            format = " ";
            exec = "${app}/bin/waybar-sysinfo";
            interval = 30;
            return-type = "json";
            on-click = "${pkgs.fuzzel}/bin/fuzzel";
          };

          # Credit: KyleOndy
          "custom/usbguard" = {
            format = "󰕓{text}";
            exec = "${app}/bin/waybar-usbguard";
            return-type = "json";
            on-click = "${app}/bin/waybar-usbguard allow";
            on-click-right = "${app}/bin/waybar-usbguard reject";
          };

          "custom/countdown" = {
            exec = "${app}/bin/waybar-countdown";
            return-type = "json";
            interval = 900;
            signal = 10;
            format = "{}";
          };

          "custom/airplane" = {
            exec = "${app}/bin/waybar-airplane";
            return-type = "json";
            interval = "once";
            signal = 12;
            format = "{}";
          };

          "custom/rebuild" = {
            exec = "${app}/bin/waybar-rebuild";
            return-type = "json";
            interval = 60;
            signal = 9;
            on-click = "swaymsg '[title=\"^nix-rebuild [0-9]+$\"] scratchpad show'";
          };

          "custom/caffeine" = {
            exec = "${app}/bin/waybar-caffeine";
            return-type = "json";
            interval = "once";
            signal = 8;
            on-click = "${app}/bin/caffeinate-toggle";
          };

          "custom/harness-status" = {
            exec = "${app}/bin/waybar-harness-status";
            return-type = "json";
            interval = 60;
            signal = 11;
            format = "{}";
            on-click = "${app}/bin/waybar-harness-status focus";
            on-click-right = "${app}/bin/waybar-harness-status clear";
          };

          "custom/nix-housing" = {
            exec = "${app}/bin/waybar-nix-housing watch ${intakeArgs}";
            restart-interval = 5;
            return-type = "json";
            format = "{}";
            on-click = "${app}/bin/waybar-nix-housing promote ${intakeArgs}";
            on-click-right = "${app}/bin/waybar-nix-housing dismiss ${intakeArgs}";
          };

          "custom/veles" = {
            exec = "${app}/bin/waybar-veles watch";
            restart-interval = 5;
            return-type = "json";
            format = "{}";
            on-click = "${app}/bin/waybar-veles accept";
            on-click-right = "${app}/bin/waybar-veles deny";
          };

          "sway/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
            sort-by-number = true;
            format = "{name}";
            persistent_workspaces = {
              "1:q" = [];
              "2:w" = [];
              "3:e" = [];
              "4:a" = [];
              "5:s" = [];
              "6:d" = [];
              "7:z" = [];
              "8:x" = [];
              "9:c" = [];
            };
            disable-click = false;
          };

          # native clock formatter cannot drop the %I zero-pad, shell date can
          "custom/clock" = {
            exec = "date +'{\"text\": \"%a %b %-d %-I:%M %p\", \"tooltip\": \"%Y-%m-%d | %H:%M\"}'";
            interval = 5;
            return-type = "json";
            on-click = launch "house-personal thunderbird -calendar";
          };

          battery = {
            format = "{icon} {capacity}%";
            format-charging = "󰂄 {capacity}%";
            format-icons = ["󰁺" "󰁼" "󰁾" "󰂀" "󰁹"];
            format-plugged = "󰚥";
            states = {
              critical = 15;
              warning = 35;
            };
            tooltip = true;
            tooltip-format = "{capacity}% — {time} · {power}W";
            tooltip-format-charging = "{capacity}% — {time} until full · {power}W";
          };

          "custom/vpn" = {
            exec = "${app}/bin/waybar-vpn";
            return-type = "json";
            interval = 3;
            signal = 13;
            on-click = "systemctl start vpn-toggle.service";
          };

          "custom/syncthing" = {
            exec = "${app}/bin/waybar-syncthing";
            return-type = "json";
            interval = 10;
            on-click = launch "xdg-open http://${config.services.syncthing.guiAddress}/";
          };

          network = {
            interval = 2;
            format-wifi = "󰖩  {essid}";
            format-ethernet = "󰈀 {ifname}";
            format-linked = "󰌗 {ifname}";
            format-disconnected = "󰖪 ";
            tooltip-format = "ap  {essid} · {signalStrength}%\nif  {ifname} · {ipaddr}/{cidr}\ngw  {gwaddr}\n\n↓ {bandwidthDownBits}\n↑ {bandwidthUpBits}";
            tooltip-format-ethernet = "if  {ifname} · {ipaddr}/{cidr}\ngw  {gwaddr}\n\n↓ {bandwidthDownBits}\n↑ {bandwidthUpBits}";
            on-click = launch "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          };

          bluetooth = {
            format = "󰂯";
            format-disabled = "󰂲";
            format-connected = "󰂱 {num_connections}";
            tooltip-format = "{controller_alias}\t{controller_address}";
            tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
            on-click = launch "${pkgs.blueman}/bin/blueman-manager";
            on-click-right = "${btToggle}";
          };

          pulseaudio = {
            format = "{icon} {volume}%";
            format-muted = "󰖁";
            format-source = "󰍬";
            format-source-muted = "󰍭";
            format-icons = {
              headphone = "󰋋";
              phone = "󰏲";
              portable = "󰄜";
              car = "󰄋";
              default = ["󰕿" "󰖀" "󰕾"];
            };
            on-click = launch "pavucontrol";
          };

          tray = {
            icon-size = 13;
            spacing = 10;
          };
        };
      };
    };
  };
}
