# @desc: Infra network addressing (cluster, hstore, mgmt, vpn, clients)
{user, ...}: {
  flake.network = let
    lan = net: net // {cidr = builtins.mapAttrs (_: ip: "${ip}/${baseNameOf net.subnet}") net.hosts;};
  in {
    pfsync.vlan = 4000;
    cluster = lan {
      subnet = "172.16.4.0/23";
      hosts = {
        m1 = "172.16.4.30";
        syncthing = "172.16.5.16";
      };
      nodes = [
        "172.16.4.11"
        "172.16.4.12"
        "172.16.4.13"
        "172.16.4.14"
      ];
      atticPort = 8090;
      atticCache = "nix-cache";
    };
    hstore = lan {
      subnet = "172.16.20.0/24";
      gateway = "172.16.20.1";
      hosts.m1 = "172.16.20.44";
    };
    mgmt = lan {
      subnet = "172.16.99.0/24";
      gateway = "172.16.99.1";
      dns = "10.255.253.1";
      hosts = {
        m1 = "172.16.99.44";
        oob = "172.16.99.15";
        framework = "172.16.99.30";
        n1 = "172.16.99.100";
        n2 = "172.16.99.101";
        n3 = "172.16.99.102";
      };
    };
    home = lan {
      subnet = "172.16.100.0/24";
      hosts = {
        steam-deck = "172.16.100.44";
        tv = "172.16.100.51";
        catbox = "172.16.100.52";
      };
    };
    vpn = lan {
      subnet = "172.16.140.0/24";
      gateway = "172.16.140.1";
      hosts = {
        slskd = "172.16.140.10";
        qbittorrent = "172.16.140.20";
        socks = "172.16.140.30";
      };
      socksPort = 1080;
    };
    offsite = lan {
      subnet = "172.16.150.0/24";
      port = 51820;
      hosts = {
        offsite-1 = "172.16.150.1";
        opnsense = "172.16.150.2";
        framework = "172.16.150.30";
      };
    };
    clients = {
      ops = ["172.16.95.0/24"];
      ${user.name} = [
        "172.16.95.30"
        "172.16.95.31"
      ];
      maxine = [
        "172.16.95.40"
        "172.16.95.41"
      ];
    };
  };
}
