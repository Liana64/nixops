{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  inherit (inputs.self.network) home clients;
  set = lib.concatStringsSep ", ";
  peers = set ([home.subnet] ++ clients.${user.name});
  port = n: toString (config.services.sunshine.settings.port + n);
in {
  # TCL 65S555 is HDMI 2.0 (600 MHz TMDS)
  # -------------------------------------
  # 4K60 fits 8-bit RGB only
  # 4K60 HDR is dithered 8-bit
  # 120 Hz is 1440p/1080p only
  # -------------------------------------
  hardware.display = {
    edid.packages = [
      (pkgs.runCommand "edid-tcl-65s555" {} "install -Dm444 ${./data/tcl-65s555.bin} $out/lib/firmware/edid/tcl-65s555.bin")
    ];
    outputs."HDMI-A-1" = {
      edid = "tcl-65s555.bin";
      mode = "e";
    };
  };

  nixpkgs.overlays = [
    (_: prev: {
      jovianPackages = prev.jovianPackages.overrideScope (_: p: {
        gamescope-session = p.gamescope-session.overrideAttrs (o: {
          postPatch =
            o.postPatch
            + ''
              substituteInPlace gamescope-session --replace-fail "-O '*',eDP-1" "-O DP-3,HDMI-A-1"
            '';
        });
      });
    })
  ];

  motd = {
    status = [
      ''
        case $(${pkgs.curl}/bin/curl -s -m1 http://127.0.0.1:${port 0}/serverinfo || true) in
          *SERVER_BUSY*) printf ' \e[32m●\e[0m sunshine streaming\n' ;;
          *SERVER_FREE*) printf ' \e[32m●\e[0m sunshine idle\n' ;;
          *) printf ' \e[31m●\e[0m sunshine down\n' ;;
        esac
      ''
    ];
    commands = [["ssh -L 8443:${home.hosts.catbox}:${port 1} ${config.networking.hostName}" "Sunshine web UI · https://localhost:8443"]];
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
  };

  networking.interfaces.enp10s0.wakeOnLan.enable = true;

  networking.firewall.extraInputRules = ''
    ip saddr { ${peers} } tcp dport { ${port (-5)}, ${port 0}, ${port 21} } accept
    ip saddr { ${peers} } udp dport { ${port 9}-${port 11}, ${port 13}, ${port 21} } accept
    ip saddr { ${set clients.${user.name}} } tcp dport ${port 1} accept
  '';
}
