# @desc: WireGuard VPN
{...}: {
  flake.modules.nixos.wireguard = {
    config,
    inputs,
    pkgs,
    lib,
    hardening,
    ...
  }: let
    inherit (inputs.self.network) wg0;
    peer = inputs.self.keys.wireguard.home.opnsense;
    secret = name: config.sops.placeholder."network/wireguard/${name}";
    wireguardConfigFile = config.sops.templates."wg0.conf".path;
    trustedNetworksFile = "/var/secrets/wireguard/trusted-networks";

    # openresolv first: systemd's resolvconf symlink resolves to resolvectl
    # otherwise, hijacking wg-quick's DNS setup and rolling the tunnel back.
    wgAutoconnect = pkgs.writeShellScript "wg-autoconnect" (''
        export PATH=${lib.makeBinPath [
          pkgs.openresolv
          pkgs.networkmanager
          pkgs.iproute2
          pkgs.wireguard-tools
          pkgs.findutils
          pkgs.gnugrep
          pkgs.coreutils
        ]}:$PATH
        export WG_CONFIG="${wireguardConfigFile}"
        export TRUSTED_NETWORKS_FILE="${trustedNetworksFile}"
      ''
      + builtins.readFile ../../modules/bin/wireguard-autoconnect);
  in
    lib.mkIf config.machineSecrets {
      sops.templates."wg0.conf".content = ''
        [Interface]
        Address = ${wg0.hosts.${config.networking.hostName}}/32
        DNS = ${wg0.gateway}
        PrivateKey = ${secret "private-key"}

        [Peer]
        PublicKey = ${peer}
        PresharedKey = ${secret "preshared-key"}
        Endpoint = ${secret "endpoint"}
        AllowedIPs = 0.0.0.0/0, ::/0
      '';

      # After spending a lot of time troubleshooting issues with wireguard that only seemed
      # to affect the linux clients, it turns out that you need to reload the wireguard server
      # service whenever you add a new peer. I hope that this comment helps someone, somewhere,
      # so that you don't have to go through what I did to figure this out. It hurt.

      # Connect to our VPN whenever we are on a network that isn't trusted. This isn't
      # entirely foolproof because someone could still spoof an SSID and BSSID, but it's
      # good enough for *me*. The trusted SSID list is a sops secret — SSIDs stay
      # out of the repo, and a missing file fails safe (nothing trusted).
      #
      # Runs as a long-lived service driven by `nmcli monitor` rather than a
      # NetworkManager dispatcher script, so the same body works under SELinux on
      # Fedora, where the dispatcher domain is confined and blocks ip/wg-quick.
      systemd.services.wg-autoconnect = {
        description = "Auto-toggle WireGuard by network trust";
        after = ["NetworkManager.service"];
        wants = ["NetworkManager.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig =
          hardening.base
          // {
            ExecStart = wgAutoconnect;
            Restart = "always";
            RestartSec = 2;
            # wg-quick sysctls src_valid_mark (full tunnel) and openresolv rewrites
            # /etc/resolv.conf in place — /proc/sys and /etc must stay writable
            ProtectKernelTunables = false;
            ProtectSystem = true;
            ProtectHome = true;
            # DAC_READ_SEARCH: the sops-managed /var/secrets tree denies plain owner
            # traversal, so caps-restricted root can't stat the config without it
            CapabilityBoundingSet = "CAP_NET_ADMIN CAP_DAC_READ_SEARCH";
            RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6"];
            RestrictNamespaces = true;
            SystemCallArchitectures = "native";
          };
      };

      networking.networkmanager.unmanaged = ["interface-name:wg0"];

      # Manual VPN toggle for waybar — wg-quick directly so it mirrors the dispatcher.
      systemd.services.vpn-toggle = {
        description = "Toggle the WireGuard tunnel";
        serviceConfig =
          hardening.base
          // {
            Type = "oneshot";
            ProtectKernelTunables = false;
            ProtectSystem = true;
            ProtectHome = true;
            CapabilityBoundingSet = "CAP_NET_ADMIN CAP_DAC_READ_SEARCH";
            RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6"];
            RestrictNamespaces = true;
            SystemCallArchitectures = "native";
            ExecStart = pkgs.writeShellScript "vpn-toggle" ''
              export PATH=${pkgs.openresolv}/bin:$PATH
              if ${pkgs.iproute2}/bin/ip link show wg0 &>/dev/null; then
                ${pkgs.wireguard-tools}/bin/wg-quick down "${wireguardConfigFile}"
              else
                ${pkgs.wireguard-tools}/bin/wg-quick up "${wireguardConfigFile}"
              fi
            '';
          };
      };

      # Let a wheel user (waybar) start vpn-toggle without authenticating.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "vpn-toggle.service" &&
              subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';
    };
}
