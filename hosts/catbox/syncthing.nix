{
  config,
  lib,
  hardening,
  inputs,
  ...
}: let
  sync = inputs.self.syncthing;
  self = config.networking.hostName;
  home = config.users.users.home.home;
  secret = name: config.sops.secrets."syncthing/${name}".path;
  folders = lib.filterAttrs (_: f: lib.elem self f.devices) sync.folders;
  peers = lib.remove self (lib.unique (lib.concatMap (f: f.devices) (lib.attrValues folders)));
in {
  sops.secrets = lib.genAttrs ["syncthing/cert" "syncthing/key"] (_: {owner = "home";});

  services.syncthing = {
    enable = true;
    user = "home";
    group = "users";
    configDir = "/var/lib/syncthing";
    cert = secret "cert";
    key = secret "key";
    guiAddress = "unix:///run/syncthing/gui.sock";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      options = {
        listenAddresses = sync.devices.${self}.addresses;
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
      };
      devices = lib.getAttrs peers sync.devices;
      folders =
        lib.mapAttrs (_: f: {
          inherit (f) label;
          path = "${home}/${f.path}";
          devices = lib.remove self f.devices;
          versioning = f.versioning or sync.versioning;
        })
        folders;
    };
  };

  systemd.tmpfiles.rules = let
    paths = lib.mapAttrsToList (_: f: f.path) folders;
    parents = lib.remove "." (lib.unique (map dirOf paths));
  in
    map (p: ''d "${home}/${p}" 0755 home users -'') (parents ++ paths);

  systemd.services.syncthing.serviceConfig =
    hardening.confined
    // {
      SystemCallFilter = ["@system-service" "~@privileged"];
      StateDirectory = "syncthing";
      ProtectHome = "tmpfs";
      BindPaths = lib.mapAttrsToList (_: f: ''"${home}/${f.path}"'') folders;
    };

  networking.firewall.extraInputRules = ''
    ip saddr { ${inputs.self.network.hstore.hosts.m1}, ${inputs.self.network.home.hosts.steam-deck} } tcp dport 22000 accept
  '';
}
