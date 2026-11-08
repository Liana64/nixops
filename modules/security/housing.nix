# @desc: nix-housing sandbox domains
{
  config,
  user,
  ...
}: let
  aspects = config.flake.modules.homeManager;
  terminfo = {pkgs, ...}: {home.packages = [pkgs.kitty.terminfo];};
in {
  flake.modules.homeManager.housing = {
    inputs,
    config,
    lib,
    pkgs,
    colors,
    hardening,
    ...
  }: let
    mix = import ../_lib/mix.nix lib;
    base = with aspects; [aliases atuin shell starship terminfo {_module.args = {inherit colors;};}];

    accents = {
      vault = "#9254de";
      dev = "#4b9bff";
      infra = "#49aa19";
      personal = "#d4b106";
      social = "#eb7cff";
      web = "#d87a16";
      web-public = "#cb2b83";
      web-ephemeral = "#8bbb11";
      web-gemini = "#d95216";
      untrusted = "#dc4446";
      agentic = "#13a8a8";
      media = "#597ef7";
      remote = "#2db7f5";
      stream = "#36cfc9";
      tasks = "#ff85c0";
      tools = "#7d8597";
      passwords = "#a0522d";
    };

    # landlock resolves the udev symlink at launch: plug the device in before starting the house
    hidraw = device: map (n: "/dev/${device}-hidraw${toString n}") (lib.range 0 15);

    houseTitle = {
      programs.zsh = {
        enable = true;
        initContent = lib.mkAfter ''
          house-title() { print -Pn '\e]2;%~\a'; }
          house-title-exec() { print -n "\e]2;''${1}\a"; }
          autoload -Uz add-zsh-hook
          add-zsh-hook precmd house-title
          add-zsh-hook preexec house-title-exec
        '';
      };
    };

    vaultGnupg = "${config.home.homeDirectory}/houses/vault/gnupg";
    vaultExtraSocket = "${vaultGnupg}/S.gpg-agent.extra";
    vaultSshSocket = "${vaultGnupg}/S.gpg-agent.ssh";

    gpgClient = {config, ...}: {
      programs.gpg = {
        enable = true;
        homedir = "${config.home.homeDirectory}/gnupg";
        settings.no-autostart = true;
        mutableKeys = false;
        mutableTrust = false;
        publicKeys = [
          {
            source = pkgs.writeText "pub.asc" inputs.self.keys."${user.name}Gpg";
            trust = "ultimate";
          }
        ];
      };
      home.file."gnupg/S.gpg-agent" = {
        source = config.lib.file.mkOutOfStoreSymlink vaultExtraSocket;
        force = true;
      };
      home.sessionVariables.SSH_AUTH_SOCK = vaultSshSocket;
    };

    vaultClientGrants = {
      socketFiles = [vaultExtraSocket vaultSshSocket];
    };

    houses = lib.filterAttrs (_: h: h.enable) config.housing.houses;
    focused = config.wayland.windowManager.sway.config.colors.focused;
    swaymsg = lib.getExe' config.wayland.windowManager.sway.package "swaymsg";
    client = c: "${c.border} ${c.background} ${c.text} ${c.indicator} ${c.childBorder}";
    tint = accent: let t = mix colors.gray accent 20; in "${t} ${t} ${focused.text} ${t} ${t}";
    tints =
      lib.mapAttrs' (name: _: lib.nameValuePair "house-${name}" (tint accents.${name})) houses
      // {"" = client focused;};
    houseTint = pkgs.writeShellScript "house-tint" ''
      ${swaymsg} -t subscribe -m '["window"]' \
        | ${lib.getExe pkgs.jq} --unbuffered -r --argjson tints ${lib.escapeShellArg (builtins.toJSON tints)} \
            'select(.change == "focus") | $tints[.container.sandbox_app_id // .container.app_id // ""] // $tints[""]' \
        | while read -r colors; do ${swaymsg} -q "client.focused $colors"; done
    '';

    portalOpen = pkgs.writeShellScript "portal-open" ''
      exec ${lib.getExe' pkgs.systemd "busctl"} --user --quiet call \
        org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
        org.freedesktop.portal.OpenURI OpenURI 'ssa{sv}' "" "$1" 0
    '';
    portalUrls = {
      xdg.desktopEntries.portal-open = {
        name = "Open on host";
        noDisplay = true;
        exec = "${portalOpen} %u";
        mimeType = ["text/html" "x-scheme-handler/http" "x-scheme-handler/https"];
      };
      xdg.configFile."mimeapps.list".force = true;
      xdg.mimeApps = {
        enable = true;
        defaultApplications =
          lib.genAttrs ["text/html" "x-scheme-handler/http" "x-scheme-handler/https"] (_: "portal-open.desktop")
          // lib.genAttrs ["x-scheme-handler/mailto" "x-scheme-handler/mid" "message/rfc822"] (_: "thunderbird.desktop")
          // {"x-scheme-handler/discord" = "vesktop.desktop";};
      };
    };

    portalOpenFile = pkgs.writeShellScript "portal-open-file" ''
      exec 3<"$1"
      exec ${lib.getExe' pkgs.systemd "busctl"} --user --quiet call \
        org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
        org.freedesktop.portal.OpenURI OpenFile 'sha{sv}' "" 3 0
    '';
    portalPdf = {
      xdg.desktopEntries.portal-open-file = {
        name = "Open file on host";
        noDisplay = true;
        exec = "${portalOpenFile} %f";
        mimeType = ["application/pdf"];
      };
      xdg.mimeApps.defaultApplications."application/pdf" = "portal-open-file.desktop";
      programs.thunderbird.profiles.default.settings."pdfjs.disabled" = true;
    };

    pdfHouse = "web-ephemeral";
    openPdf = let
      h = config.housing.houses.${pdfHouse};
    in
      intake.openPdf {
        name = "open-pdf";
        launch = "${h.runner}/bin/house-${pdfHouse} ${h.hm.homeManagerConfiguration.config.home.path}/bin/firefox --new-tab";
      };

    officeTypes = [
      "application/vnd.oasis.opendocument.text"
      "application/vnd.oasis.opendocument.spreadsheet"
      "application/vnd.oasis.opendocument.presentation"
      "application/vnd.oasis.opendocument.graphics"
      "application/msword"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.ms-excel"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.ms-powerpoint"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/rtf"
    ];
    houseOpen = let
      h = config.housing.houses.personal;
      real = lib.replaceStrings ["$NIX_HOUSING_REAL_HOME"] [config.home.homeDirectory];
    in
      intake.houseOpen {
        name = "house-open";
        launch = "${h.runner}/bin/house-personal ${h.hm.homeManagerConfiguration.config.home.path}/bin/libreoffice";
        dirs = map real personalDirs;
        drop = real drop;
      };

    projects = "$NIX_HOUSING_REAL_HOME/Projects";
    notebook = "$NIX_HOUSING_REAL_HOME/Notebook";
    personalDirs = [notebook "$NIX_HOUSING_REAL_HOME/Documents" drop];
    dillo = "$NIX_HOUSING_REAL_HOME/.dillo";
    drop = "$NIX_HOUSING_REAL_HOME/houses/shared/drop";
    velesDir = "$NIX_HOUSING_REAL_HOME/houses/shared/veles";

    intake = import ../_lib/house-intake.nix {inherit pkgs lib hardening config;};

    sharedDrop = let
      host = config;
      shared = "${host.home.homeDirectory}/houses/shared/drop";
    in
      {config, ...}: let
        # Thunar is a unique GApplication; on the shared bus it would hand folders to another house's instance
        bus = pkgs.writeText "thunar-bus.conf" ''
          <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
          <busconfig>
            <type>session</type>
            <listen>unix:tmpdir=${config.xdg.cacheHome}</listen>
            <auth>EXTERNAL</auth>
            <policy context="default">
              <allow send_destination="*"/>
              <allow own="*"/>
            </policy>
          </busconfig>
        '';
        thunar = pkgs.symlinkJoin {
          name = "thunar-private-bus";
          paths = [pkgs.thunar];
          postBuild = ''
            ln -sf ${pkgs.writeShellScript "thunar" ''
              mkdir -p ${config.xdg.cacheHome}
              exec ${pkgs.dbus}/bin/dbus-run-session --config-file=${bus} -- ${pkgs.thunar}/bin/thunar "$@"
            ''} $out/bin/thunar
          '';
        };
      in {
        xdg.configFile =
          lib.genAttrs ["gtk-3.0/settings.ini" "gtk-3.0/gtk.css" "gtk-4.0/settings.ini" "gtk-4.0/gtk.css"] (f: {inherit (host.xdg.configFile.${f}) source;})
          // {"gtk-3.0/bookmarks".text = "file://${shared} Shared\n";};
        programs.firefox.policies.DefaultDownloadDirectory = "${config.home.homeDirectory}/Downloads";
        home.packages = [thunar] ++ map (t: t.package) (with host.gtk; [theme iconTheme cursorTheme font]);
        xdg.mimeApps = {
          enable = true;
          defaultApplications."inode/directory" = "thunar.desktop";
        };
      };

    inherit (inputs.self.network) vpn;

    webCapabilities = {
      gui.enable = true;
      gpu.enable = true;
      pulseAudio.enable = true;
      namespacing.proc = true;
      sessionDbus.own = ["org.mozilla.firefox.*"];
      landlock = {
        connectTcpPorts = [53 80 443 8006 8080 8443 5900];
        rwDirs = [drop];
      };
    };
    refreshWaybar = "${pkgs.systemd}/bin/systemctl --user kill --kill-whom=main --signal=SIGRTMIN+13 waybar.service";
    ephemeralSocket = "${config.housing.houses.web-ephemeral.houseHomeDir}/.socks.sock";
    caldav = "calendar.milberry.org";
    caldavSocket = "tasks-caldav.sock";
  in {
    imports = [inputs.nix-housing.homeManagerModules.default];

    systemd.user.sockets.ephemeral-socks = {
      Unit = {
        Description = "web-ephemeral session socket to the VLAN 140 SOCKS proxy";
        StopWhenUnneeded = true;
      };
      Socket = {
        ListenStream = ephemeralSocket;
        SocketMode = "0600";
        RemoveOnStop = true;
        ExecStartPost = "-${refreshWaybar}";
        ExecStopPost = "-${refreshWaybar}";
      };
    };

    systemd.user.services.ephemeral-socks = {
      Unit.Description = "Relay web-ephemeral to the VLAN 140 SOCKS proxy";
      Service =
        hardening.confined
        // {
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10s ${vpn.hosts.socks}:${toString vpn.socksPort}";
        };
    };

    systemd.user.sockets.tasks-caldav = {
      Unit.Description = "tasks house relay socket to ${caldav}";
      Socket = {
        ListenStream = "%t/${caldavSocket}";
        SocketMode = "0600";
        RemoveOnStop = true;
      };
      Install.WantedBy = ["sockets.target"];
    };

    systemd.user.services.tasks-caldav = {
      Unit.Description = "Relay the tasks house to ${caldav}:443";
      Service =
        hardening.confined
        // {
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10s ${caldav}:443";
        };
    };

    housing.enable = true;
    housing.shellPromptPrefix = false;
    housing.houses = {
      vault = {
        hm.config = {config, ...}: {
          imports = [aspects.gpg terminfo houseTitle];
          programs.gpg.homedir = "${config.home.homeDirectory}/gnupg";
          services.gpg-agent.pinentry.package = pkgs.pinentry-qt;
        };
        capabilities = {
          wayland.enable = true;
          landlock.socketDirs = ["/run/pcscd" "/var/run/pcscd"];
        };
      };

      passwords = {
        hm.config = {
          imports = base ++ [houseTitle];
          home.packages = [
            (pkgs.symlinkJoin {
              name = "bitwarden-desktop";
              paths = [pkgs.bitwarden-desktop];
              nativeBuildInputs = [pkgs.makeWrapper];
              postBuild = "wrapProgram $out/bin/bitwarden --prefix LD_LIBRARY_PATH : ${lib.getLib (import ../_lib/udev-chase.nix pkgs)}/lib";
            })
          ];
          home.sessionVariables.NIXOS_OZONE_WL = "1";
        };
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          namespacing.proc = true;
          landlock = {
            connectTcpPorts = [443];
            deviceFiles = hidraw "yubikey";
          };
        };
      };

      dev = {
        hm.config.imports =
          base
          ++ [
            houseTitle
            gpgClient
            aspects.agentic
            aspects.cliPackages
            aspects.devPackages
            aspects.dvcs
            aspects.helix
            aspects.veles
          ];
        capabilities.namespacing.proc = true;
        capabilities.landlock =
          vaultClientGrants
          // {
            connectTcpPorts = [22 443];
            bindTcpPorts = [0];
            roFiles = ["/var/secrets/eek/gateway-key"];
            rwDirs = [projects drop velesDir];
          };
      };

      infra = {
        hm.config.dconf.enable = false;
        hm.config.programs.zsh.initContent = ''[[ -o login ]] && cd "${projects}/Software/home-infra"'';
        hm.config.imports =
          base
          ++ [
            houseTitle
            gpgClient
            aspects.devPackages
            aspects.infra
            aspects.k9s
            aspects.netshoot
            aspects.ssh
            aspects.stylix
            aspects.veles
          ];
        capabilities.landlock =
          vaultClientGrants
          // {
            connectTcpPorts = [22 6443];
            rwDirs = [projects drop velesDir];
          };
      };

      personal = {
        hm.config = {
          imports =
            base
            ++ [
              houseTitle
              portalUrls
              portalPdf
              sharedDrop
              aspects.halloy
              aspects.iamb
              aspects.obsidian
              aspects.signal
              aspects.thunderbird
              aspects.vesktop
            ];
          home.packages = [pkgs.libreoffice];
          home.sessionVariables = {
            NIXOS_OZONE_WL = "1";
            XDG_SESSION_TYPE = "wayland";
          };
        };
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          pulseAudio.enable = true;
          namespacing.proc = true;
          sessionDbus.talk = ["org.freedesktop.portal.*" "org.freedesktop.Notifications" "org.freedesktop.secrets" "org.kde.StatusNotifierWatcher"];
          sessionDbus.own = ["org.freedesktop.StatusNotifierItem-2-1"];
          landlock = {
            connectTcpPorts = [443 1025 1143 6697];
            rwDirs = personalDirs ++ ["/dev/shm" "/tmp"];
          };
          # libreoffice binds its instance pipe in a hard-coded /tmp; give the house its own
          execWrappers.privateTmp = lib.hm.dag.entryBetween ["namespacingDrop"] ["namespacing"] ''
            set -eu
            exec 3<"$NIX_HOUSING_HOUSE_TMPDIR"
            ${pkgs.util-linux}/bin/mount -t tmpfs -o mode=1777,nosuid,nodev tmpfs /tmp
            ${pkgs.coreutils}/bin/mkdir -p "$NIX_HOUSING_HOUSE_TMPDIR"
            ${pkgs.util-linux}/bin/mount --bind /proc/self/fd/3 "$NIX_HOUSING_HOUSE_TMPDIR"
            exec 3<&-
            exec "$@"
          '';
        };
      };

      social = {
        hm.config = {
          imports = base ++ [houseTitle portalUrls aspects.fluxer];
          home.sessionVariables.NIXOS_OZONE_WL = "1";
        };
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          pulseAudio.enable = true;
          namespacing.proc = true;
          sessionDbus.talk = ["org.freedesktop.portal.*" "org.freedesktop.Notifications" "org.kde.StatusNotifierWatcher"];
          landlock.connectTcpPorts = [443];
        };
      };

      web-gemini = {
        hm.config.imports =
          base
          ++ [
            houseTitle
            sharedDrop
            aspects.dillo
          ];
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          pulseAudio.enable = true;
          namespacing.proc = true;
          landlock = {
            connectTcpPorts = [53 80 443];
            rwDirs = [drop dillo];
          };
        };
      };

      web = {
        hm.config.imports =
          base
          ++ [
            houseTitle
            sharedDrop
            aspects.chromium
            aspects.firefox
          ];
        exportDesktopEntries = true;
        capabilities = lib.recursiveUpdate webCapabilities {
          landlock.connectTcpPorts =
            webCapabilities.landlock.connectTcpPorts
            ++ [
              (lib.toInt (lib.last (lib.splitString ":" config.services.syncthing.guiAddress)))
              config.d2.watchPort
            ];
          landlock.deviceFiles = map (n: "/dev/hidraw${toString n}") (lib.range 0 15);
        };
      };

      web-public = {
        hm.config = {
          imports =
            base
            ++ [
              houseTitle
              sharedDrop
              aspects.firefox
              aspects.zoom
            ];
          firefox.role = "public";
        };
        exportDesktopEntries = true;
        capabilities = lib.recursiveUpdate webCapabilities {
          sessionDbus.talk = ["org.freedesktop.Notifications"];
          landlock.deviceFiles = ["/dev/video0" "/dev/video1"];
        };
      };

      web-ephemeral = {
        hm.config = {
          imports =
            base
            ++ [
              houseTitle
              sharedDrop
              aspects.firefox
            ];
          firefox.role = "ephemeral";
          programs.firefox.profiles.ephemeral.settings = {
            "network.proxy.type" = 1;
            "network.proxy.socks" = "file://${ephemeralSocket}";
            "network.proxy.socks_version" = 5;
            "network.proxy.socks5_remote_dns" = true;
            "network.proxy.failover_direct" = false;
            "network.proxy.no_proxies_on" = "";
          };
        };
        exportDesktopEntries = true;
        capabilities = lib.recursiveUpdate webCapabilities {
          # loopback-only netns: the proxy socket is the only way out, for every protocol
          namespacing.net = true;
          landlock.connectTcpPorts = [];
          landlock.roDirs = ["$NIX_HOUSING_REAL_XDG_RUNTIME_DIR/${intake.pdfStage}"];
          execWrappers.ephemeralSession = lib.hm.dag.entryBetween ["namespacing"] ["dirSetup"] ''
            if ! ${pkgs.systemd}/bin/systemctl --user --quiet is-active ephemeral-socks.socket; then
              ff="$NIX_HOUSING_HOUSE_HOME/.mozilla/firefox"
              [ -d "$ff/ephemeral" ] && ${pkgs.findutils}/bin/find "$ff/ephemeral" -mindepth 1 -maxdepth 1 \
                ! -type l ! -name chrome ! -name search.json.mozlz4 -exec ${pkgs.coreutils}/bin/rm -rf {} +
              ${pkgs.coreutils}/bin/rm -rf "$ff/ephemeral/lock" "$ff/Crash Reports" "$ff/Pending Pings" "$ff/Profile Groups" "$NIX_HOUSING_HOUSE_HOME/.cache/mozilla"
            fi
            [ -S "$XDG_RUNTIME_DIR/systemd/private" ] || exec "$@"
            exec ${pkgs.systemd}/bin/systemd-run --user --scope --quiet --collect \
              -p Wants=ephemeral-socks.socket -p After=ephemeral-socks.socket -- "$@"
          '';
        };
      };

      agentic = {
        hm.config.imports =
          base
          ++ [
            houseTitle
            aspects.agentic
            aspects.cliPackages
            aspects.devPackages
            aspects.helix
            aspects.veles
          ];
        capabilities = {
          namespacing.proc = true;
          landlock = {
            connectTcpPorts = [443];
            bindTcpPorts = [0];
            roFiles = ["/var/secrets/eek/gateway-key"];
            rwDirs = [drop velesDir];
            # fixed-output derivations fetch daemon-side, outside landlock — the 443 limit is not an exfiltration boundary
            socketFiles = ["/nix/var/nix/daemon-socket/socket"];
          };
        };
      };

      media = {
        hm.config = {config, ...}: {
          imports = base ++ [houseTitle aspects.fooyin aspects.stylix];
          dconf.enable = false;
          home.file.Music.source = config.lib.file.mkOutOfStoreSymlink "/mnt/m1/media/Music";
        };
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          pulseAudio.enable = true;
          namespacing.proc = true;
          sessionDbus.own = ["org.mpris.MediaPlayer2.fooyin"];
          landlock.rwDirs = ["/mnt/m1/media"];
          execWrappers.qtLockSweep = lib.hm.dag.entryBetween ["namespacing"] ["dirSetup"] ''
            for l in "$NIX_HOUSING_HOUSE_TMPDIR"/kdsingleapp-*.lock; do
              [ -e "$l" ] && ${pkgs.util-linux}/bin/flock -n "$l" true && rm -f "$l" "''${l%.lock}"
            done
            exec "$@"
          '';
        };
      };

      remote = {
        hm.config.imports = base ++ [houseTitle aspects.remmina];
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          namespacing.proc = true;
          sessionDbus.own = ["org.remmina.Remmina"];
          landlock.connectTcpPorts = [3389 5900];
        };
      };

      stream = {
        hm.config = {
          imports = base ++ [houseTitle];
          home.packages = [pkgs.moonlight-qt];
          home.sessionVariables.SDL_JOYSTICK_DISABLE_UDEV = "1";
        };
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          pulseAudio.enable = true;
          namespacing.proc = true;
          # GameStream control plane; video, audio, input and mDNS are UDP, which landlock does not govern
          landlock = {
            connectTcpPorts = [47984 47989 48010];
            deviceDirs = ["/dev/input"];
          };
        };
      };

      tasks = {
        hm.config.imports = base ++ [houseTitle aspects.planify];
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          namespacing.net = true;
          sessionDbus.own = ["io.github.alainm23.planify" "io.github.alainm23.planify.*"];
          landlock = {
            connectTcpPorts = [443];
            bindTcpPorts = [443];
            socketFiles = ["$NIX_HOUSING_REAL_XDG_RUNTIME_DIR/${caldavSocket}"];
          };
          execWrappers.caldavNet = lib.hm.dag.entryBetween ["namespacingDrop" "procMask"] ["namespacing"] ''
            set -eu
            ${pkgs.util-linux}/bin/mount --bind ${pkgs.writeText "tasks-hosts" "127.0.0.1 localhost ${caldav}\n::1 localhost\n"} /etc/hosts
            echo 0 > /proc/sys/net/ipv4/ip_unprivileged_port_start
            exec "$@"
          '';
          execWrappers.caldavRelay = lib.hm.dag.entryBetween ["envFilter"] ["landlock"] ''
            ${pkgs.systemd}/bin/systemd-socket-activate -l 127.0.0.1:443 \
              ${pkgs.systemd}/lib/systemd/systemd-socket-proxyd "$NIX_HOUSING_REAL_XDG_RUNTIME_DIR/${caldavSocket}" &
            exec "$@"
          '';
        };
      };

      tools = {
        hm.config = {
          imports = base ++ [houseTitle aspects.keyboard];
          home.packages = [pkgs.supercell-wx];
        };
        exportDesktopEntries = true;
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          pulseAudio.enable = true;
          namespacing.proc = true;
          landlock = {
            connectTcpPorts = [80 443];
            deviceFiles = hidraw "vial";
            rwDirs = ["/dev/shm"];
          };
        };
      };

      untrusted = {
        hm.config.imports = [terminfo houseTitle sharedDrop];
        capabilities = {
          gui.enable = true;
          gpu.enable = true;
          pulseAudio.enable = true;
          landlock.rwDirs = [drop];
        };
      };
    };

    systemd.user.services.vault-agent = {
      Unit.Description = "gpg-agent inside the vault house";
      Service = {
        ExecStart = "${config.housing.houses.vault.runner}/bin/house-vault ${pkgs.gnupg}/bin/gpg-agent --daemon --no-detach";
        Restart = "on-failure";
      };
      Unit.After = ["graphical-session.target"];
      Install.WantedBy = ["graphical-session.target"];
    };

    systemd.user.services."house-promote@" = {
      Unit.Description = "Copy pending %i house files into the host";
      Service = intake.service {mode = "promote";};
    };

    systemd.user.services."house-dismiss@" = {
      Unit.Description = "Mark pending %i house files as seen";
      Service = intake.service {mode = "dismiss";};
    };

    systemd.user.tmpfiles.rules =
      [
        "d %h/houses/shared 0700 - - -"
        "d %h/houses/shared/drop 0700 - - -"
        "d %h/houses/shared/veles 0700 - - -"
        "d %t/${intake.pdfStage} 0700 - - -"
      ]
      ++ lib.concatMap (h: map (d: "d %h/${d}/${h} 0700 - - -") intake.dirs ++ ["d %S/house-intake/${h} 0700 - - -"]) intake.houses;

    xdg.desktopEntries =
      lib.mapAttrs' (name: h:
        lib.nameValuePair "house-${name}" {
          name = "kitty [${name}]";
          genericName = "Terminal";
          comment = "Login shell inside the ${name} house";
          icon = "kitty";
          exec = "${lib.getExe pkgs.kitty} --class house-${name} ${h.runner}/bin/house-${name}";
          categories = ["System" "TerminalEmulator"];
        })
      houses
      // {
        open-pdf = {
          name = "PDF [${pdfHouse}]";
          noDisplay = true;
          exec = "${lib.getExe openPdf} %f";
          mimeType = ["application/pdf"];
        };
        house-open = {
          name = "LibreOffice [personal]";
          noDisplay = true;
          exec = "${lib.getExe houseOpen} %F";
          mimeType = officeTypes;
        };
      };

    xdg.mimeApps.defaultApplications = lib.genAttrs officeTypes (_: "house-open.desktop");

    xdg.dataFile."applications/iamb.house-personal.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=iamb [personal]
      GenericName=Matrix Client [personal]
      Icon=iamb
      Categories=Network;InstantMessaging;Chat;
      Exec=${lib.getExe pkgs.kitty} --class house-personal --title iamb ${config.housing.houses.personal.runner}/bin/house-personal iamb
    '';

    wayland.windowManager.sway.config.window.commands = lib.concatLists (lib.mapAttrsToList (name: _: [
        {
          criteria.sandbox_app_id = "house-${name}";
          command = ''title_format "[${name}] %title"'';
        }
        {
          criteria.app_id = "^house-${name}$";
          command = ''title_format "[${name}] %title"'';
        }
      ])
      houses);

    systemd.user.services.house-tint = lib.mkIf config.wayland.windowManager.sway.enable {
      Unit = {
        Description = "Per-house titlebar tint";
        After = ["graphical-session.target"];
        Requisite = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Install.WantedBy = ["graphical-session.target"];
      Service =
        hardening.confined
        // {
          ExecStart = "${houseTint}";
          Restart = "on-failure";
          ProtectHome = "read-only";
        };
    };
  };
}
