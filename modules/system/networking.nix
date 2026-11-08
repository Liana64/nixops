# @desc: NetworkManager + nftables firewall
{...}: {
  flake.modules.nixos.networking = {lib, ...}: {
    networking.networkmanager.enable = true;
    networking.useDHCP = lib.mkDefault true;

    # Per-network MAC keyed on SSID
    # Override per network:
    #   nmcli connection modify <name> 802-11-wireless.cloned-mac-address permanent
    networking.networkmanager.wifi.macAddress = "stable-ssid";

    # iptables is pretty old by now
    networking.nftables.enable = true;

    networking.firewall = {
      enable = true;
      logRefusedConnections = true;

      # Allow localsend
      allowedTCPPorts = [53317];
      allowedUDPPorts = [53317];
    };
  };
}
