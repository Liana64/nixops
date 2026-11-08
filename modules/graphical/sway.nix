# @desc: Sway WM + session env vars
{...}: {
  flake.modules.homeManager.sway = {
    config,
    lib,
    pkgs,
    flakePath,
    ...
  }: let
    app = pkgs.symlinkJoin {
      name = "sway-scripts";
      paths = with pkgs; [
        (writeShellScriptBin "sway-screenshot-all" (builtins.readFile ../../modules/bin/sway-screenshot-all))
        (writeShellScriptBin "sway-screenshot-area" (builtins.readFile ../../modules/bin/sway-screenshot-area))
        (writeShellScriptBin "nix-rebuild-sway" (builtins.readFile ../../modules/bin/nix-rebuild-sway))
        (writeShellScriptBin "caffeinate-toggle" (builtins.readFile ../../modules/bin/caffeinate-toggle))
        (writeShellScriptBin "airplane-toggle" (builtins.readFile ../../modules/bin/airplane-toggle))
        usbguard
      ];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/sway-screenshot-all      --prefix PATH : $out/bin
        wrapProgram $out/bin/sway-screenshot-area     --prefix PATH : $out/bin
        wrapProgram $out/bin/nix-rebuild-sway         --prefix PATH : $out/bin:${lib.makeBinPath (with pkgs; [coreutils gnugrep libnotify sway systemd util-linux])} --set-default NH_FLAKE ${flakePath}
        wrapProgram $out/bin/airplane-toggle          --prefix PATH : ${lib.makeBinPath (with pkgs; [networkmanager bluez libnotify coreutils systemd])}
      '';
    };
  in {
    programs.swaylock = {
      enable = true;
      settings = {
        daemonize = true;
        indicator-caps-lock = true;
        indicator-radius = 80;
      };
    };

    systemd.user.targets.graphical.Unit.Wants = ["xdg-desktop-autostart.target"];
    wayland.windowManager.sway = {
      enable = true;
      systemd = {
        enable = true;
        variables = [
          "DISPLAY"
          "WAYLAND_DISPLAY"
          "SWAYSOCK"
          "XDG_CURRENT_DESKTOP"
          "XDG_SESSION_TYPE"
          "NIXOS_OZONE_WL"
          "XCURSOR_THEME"
          "XCURSOR_SIZE"
          "PATH"
          "XDG_DATA_DIRS"
        ];
      };
      xwayland = false;
      package = pkgs.sway;
      wrapperFeatures.gtk = true;

      extraConfig = ''
        # Inhibit idle if any window is fullscreen
        for_window [app_id=".*"] inhibit_idle fullscreen

        assign [app_id="kitty-startup"] workspace 1:q
        assign [app_id="thunderbird"] workspace 3:e
        assign [app_id="Element"] workspace 5:s
        assign [app_id="org.squidowl.halloy"] workspace 5:s
        assign [app_id="signal"] workspace 5:s
        assign [app_id="vesktop"] workspace 5:s
        assign [app_id="house-personal" title="^iamb"] workspace 5:s
        assign [app_id="md.Obsidian"] workspace 6:d
        assign [app_id="org.fooyin.fooyin"] workspace 8:x

        # Settings
        font pango:JetBrainsMono Nerd Font 10
        titlebar_padding 3 1
        title_align center

        # Disable laptop display when using a dock
        bindswitch --reload --locked lid:on output eDP-1 disable
        bindswitch --reload --locked lid:off output eDP-1 enable

        exec_always --no-startup-id autotiling-rs
      '';
      config = {
        terminal = "kitty";
        menu = "fuzzel";
        startup = [
          {command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";}
          {command = "kitty --class kitty-startup";}
        ];
        window.commands = [
          {
            criteria = {title = "^nix-rebuild [0-9]+$";};
            command = "floating enable, resize set 800 400, move scratchpad";
          }
          {
            criteria = {title = "numbat";};
            command = "floating enable, resize set 800 500, move position center";
          }
          {
            criteria = {title = "task-add";};
            command = "floating enable, resize set 600 120, move position center";
          }
          {
            criteria = {title = "task-done";};
            command = "floating enable, resize set 720 500, move position center";
          }
          {
            criteria = {
              app_id = "firefox";
              title = "^(Save|Open|Enter name of|Select).*";
            };
            command = "floating enable, resize set 900 650, move position center";
          }
          {
            criteria = {
              app_id = "^thunar$";
              title = "^(?!.* - Thunar$)";
            };
            command = "floating enable, move position center";
          }
        ];
        modifier = "Mod1";

        gaps = {
          inner = 0;
          outer = 0;
          smartGaps = false;
          smartBorders = "on";
        };
        window.titlebar = true;
        window.border = 2;
        floating.border = 2;
        floating.titlebar = true;

        keybindings = let
          cfg = config.wayland.windowManager.sway.config;
          mod = cfg.modifier;
          sup = "Mod4";
          powerMode = ''mode "power: (p) poweroff · (s) suspend · (r) reboot · (g) logout · (l) lock · (c) caffeinate · (a) airplane"'';
        in {
          "XF86PowerOff" = powerMode;
          "XF86AudioMedia" = powerMode;
          "XF86Explorer" = powerMode;

          "print" = "exec '${app}/bin/sway-screenshot-area'";
          "Shift+print" = "exec '${app}/bin/sway-screenshot-all'";

          "${sup}+Shift+1" = "exec '${app}/bin/sway-screenshot-all'";
          "${sup}+Shift+2" = "exec '${app}/bin/sway-screenshot-area'";

          "${sup}+Shift+3" = "exec 'grim - | wl-copy'";
          "${sup}+Shift+4" = "exec 'grim -g \"$(slurp)\" - | wl-copy'";

          "XF86MonBrightnessUp" = "exec 'brightnessctl set 5%+'";
          "XF86MonBrightnessDown" = "exec 'brightnessctl set 5%-'";

          "XF86AudioPlay" = "exec playerctl play-pause";
          "XF86AudioPause" = "exec playerctl play-pause";
          "XF86AudioPrev" = "exec playerctl previous";
          "XF86AudioNext" = "exec playerctl next";
          "XF86AudioStop" = "exec playerctl stop";

          "XF86AudioRaiseVolume" = "exec wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

          #"${sup}+c" = "exec wtype -P XF56Copy";
          #"${sup}+v" = "exec wtype -P XF56Paste";
          #"${sup}+x" = "exec wtype -P XF56Cut";

          "${mod}+Return" = "exec ${cfg.terminal}";
          "${mod}+Shift+Return" = "exec ${cfg.terminal} --session startup.session";

          "${mod}+Shift+r" = "reload";
          "${mod}+Control+Shift+r" = "exec ${app}/bin/nix-rebuild-sway";
          "${mod}+Control+Shift+g" = "exec '${app}/bin/nix-rebuild-sway add'";
          "${sup}+d" = "exec ${cfg.menu}";

          "${mod}+Space" = "exec ${cfg.menu}";
          "${mod}+Shift+Space" = "exec 'kitty --title numbat ${pkgs.numbat}/bin/numbat'";

          "${mod}+Left" = "focus left";
          "${mod}+Down" = "focus down";
          "${mod}+Up" = "focus up";
          "${mod}+Right" = "focus right";

          "${mod}+Shift+Left" = "move left";
          "${mod}+Shift+Down" = "move down";
          "${mod}+Shift+Up" = "move up";
          "${mod}+Shift+Right" = "move right";

          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          "${mod}+Tab" = "focus next";
          "${mod}+Shift+Tab" = "focus prev";

          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";

          "${mod}+Shift+m" = "move scratchpad";
          "${mod}+m" = "scratchpad show";

          "${mod}+Shift+b" = "splith";
          "${mod}+Shift+v" = "splitv";
          "${mod}+f" = "fullscreen";
          "${mod}+p" = "focus parent";

          "${mod}+minus" = "resize shrink width 50px";
          "${mod}+plus" = "resize grow width 50px";

          "${mod}+underscore" = "resize shrink height 50px";
          "${mod}+equal" = "resize grow height 50px";

          # "${mod}+g" = "layout stacking";
          # "${mod}+t" = "layout tabbed";

          "${mod}+b" = "layout toggle split";

          "${mod}+Shift+f" = "floating toggle";
          "${mod}+y" = "focus mode_toggle";

          "${mod}+q" = "workspace 1:q";
          "${mod}+w" = "workspace 2:w";
          "${mod}+e" = "workspace 3:e";
          "${mod}+a" = "workspace 4:a";
          "${mod}+s" = "workspace 5:s";
          "${mod}+d" = "workspace 6:d";
          "${mod}+z" = "workspace 7:z";
          "${mod}+x" = "workspace 8:x";
          "${mod}+c" = "workspace 9:c";

          "${mod}+Shift+q" = "move container to workspace 1:q";
          "${mod}+Shift+w" = "move container to workspace 2:w";
          "${mod}+Control+Shift+w" = "exec house-web firefox";
          "${mod}+Shift+e" = "move container to workspace 3:e";
          "${mod}+Control+Shift+e" = "workspace 3:e; exec house-personal thunderbird";
          "${mod}+Shift+a" = "move container to workspace 4:a";
          "${mod}+Ctrl+Shift+a" = "workspace 4:a; exec house-tasks planify";
          "${mod}+Shift+s" = "move container to workspace 5:s";
          "${mod}+Control+Shift+s" = "workspace 5:s; exec house-personal signal-desktop";
          "${mod}+Control+Shift+v" = "workspace 5:s; exec house-personal vesktop";
          "${mod}+Control+Shift+i" = "workspace 5:s; exec kitty --class house-personal --title iamb house-personal iamb";
          "${mod}+Shift+d" = "move container to workspace 6:d";
          "${mod}+Control+Shift+d" = "workspace 6:d; exec house-personal obsidian";
          "${mod}+Shift+z" = "move container to workspace 7:z";
          "${mod}+Shift+x" = "move container to workspace 8:x";
          "${mod}+Shift+c" = "move container to workspace 9:c";
          "${mod}+Control+Shift+x" = "workspace 8:x; exec house-media fooyin";
          "${mod}+Control+Return" = "exec thunar";
          "${mod}+Control+Shift+z" = "exec house-web-public zoom-web";

          "${sup}+Shift+q" = "kill";
        };

        input = {
          "type:touchpad" = {
            tap = "enabled";
            tap_button_map = "lrm";
            middle_emulation = "enabled";
            natural_scroll = "disabled";
            drag_lock = "disabled";
            scroll_factor = "0.7";
            accel_profile = "adaptive";
            pointer_accel = "0.15";
          };

          "type:pointer" = {
            accel_profile = "flat";
            pointer_accel = "-0.15";
          };

          "*" = {
            xkb_layout = "us";
            repeat_delay = "200";
            repeat_rate = "40";
          };
        };

        output = {
          "eDP-1" = {
            # resolution = "2880x1920@120Hz";
            resolution = "2880x1920@60Hz";
            position = "920,1440";
            #scale = "1.9";
            scale = "1.8";
          };
          "DP-5" = {
            resolution = "3440x1440@144Hz";
            position = "0,0";
          };
        };

        bars = [
          {
            id = "power";
            mode = "hide";
            hiddenState = "hide";
            command = "${pkgs.coreutils}/bin/true";
            statusCommand = null;
            extraConfig = "modifier none";
          }
        ];

        modes = {
          "power: (p) poweroff · (s) suspend · (r) reboot · (g) logout · (l) lock · (c) caffeinate · (a) airplane" = {
            p = "exec swaymsg 'mode default' && systemctl poweroff";
            s = "exec swaymsg 'mode default' && systemctl suspend";
            r = "exec swaymsg 'mode default' && systemctl reboot";
            g = "exec swaymsg 'mode default' && systemctl --user stop sway-session.target && systemctl --user stop graphical-session.target && swaymsg exit";
            l = "exec swaymsg 'mode default' && systemctl --user start swaylock.service";
            c = "exec swaymsg 'mode default' && ${app}/bin/caffeinate-toggle";
            a = "exec swaymsg 'mode default' && ${app}/bin/airplane-toggle";
            Return = "mode default";
            Escape = "mode default";
          };
        };
        focus.followMouse = false;
        focus.newWindow = "focus";
      };
    };

    xdg.configFile."autostart/blueman.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Hidden=true
    '';

    home.sessionVariables = {
      DESKTOP_SESSION = "sway";
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";
      XDG_DATA_DIRS = "$HOME/.nix-profile/share:${config.home.profileDirectory}/share:$XDG_DATA_DIRS";

      # Force native Wayland for Electron/Chromium apps (no XWayland fallback)
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      OZONE_PLATFORM = "wayland";
      NIXOS_OZONE_WL = "1";

      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };
}
