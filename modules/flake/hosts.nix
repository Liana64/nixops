# @desc: Assembles nixosConfigurations + homeConfigurations from aspects
{
  config,
  inputs,
  lib,
  user,
  ...
}: let
  inherit (inputs) self nixpkgs home-manager;

  homeAspects =
    lib.attrVals [
      "agentic"
      "aliases"
      "atuin"
      "auditd"
      "benchmarks"
      "cache"
      "cliPackages"
      "ctar"
      "d2"
      "dconf"
      "desktopPackages"
      "devPackages"
      "dice"
      "dvcs"
      "flatpak"
      "frame"
      "frameworkDsp"
      "fuzzel"
      "gpg"
      "hardening-probe"
      "helix"
      "housing"
      "infra"
      "installer"
      "k9s"
      "kitty"
      "mako"
      "mime"
      "nushell"
      "persist-diff"
      "shell"
      "ssh"
      "starship"
      "stylix"
      "sway"
      "swaybg"
      "swayidle"
      "syncthing"
      "theme"
      "troubleshootPackages"
      "veles"
      "waybar"
      "xdgUserdirs"
    ]
    config.flake.modules.homeManager;

  base = ["hardwareTools" "nixCache" "nixDaemon" "secrets" "sshd" "time" "users"];
  hardened = base ++ ["hardening" "journald" "noDefaults" "noexec" "storeVerify"];
  server = hardened ++ ["motd"];
  serverOnly = ["hypervisor" "zfsRollback"];
  workstation =
    hardened
    ++ [
      "audio"
      "auditd"
      "auditdWorkstation"
      "boot"
      "compositor"
      "email"
      "faillock"
      "files"
      "flatpak"
      "fonts"
      "hardeningWorkstation"
      "impermanence"
      "keyboard"
      "keyring"
      "logFlood"
      "networking"
      "nfsClient"
      "nushell"
      "packages"
      "ssd"
      "sudo"
      "theme"
      "usbguard"
      "virtualization"
      "wireguard"
      "wireless"
      "yubikey"
    ];
  laptop = workstation ++ ["frameworkHardware" "laptop"];

  hosts = {
    framework = {
      system = "x86_64-linux";
      aspects = laptop ++ ["maintenanceNotify" "perfTools" "remoteBuilds"];
    };
    portable = {
      system = "x86_64-linux";
      aspects = laptop;
    };
    catbox = {
      system = "x86_64-linux";
      channel = inputs.nixpkgs-unstable;
      aspects = base ++ ["audio" "files" "motd" "networking" "noDefaults"];
      home = false;
    };
    m1 = {
      system = "x86_64-linux";
      aspects = server ++ ["auditd" "hypervisor"];
      home = false;
    };
    n1 = {
      system = "x86_64-linux";
      aspects = server ++ serverOnly;
      home = false;
    };
    n2 = {
      system = "x86_64-linux";
      aspects = server ++ serverOnly;
      home = false;
    };
    n3 = {
      system = "x86_64-linux";
      aspects = server ++ serverOnly;
      home = false;
    };
    offsite-1 = {
      system = "aarch64-linux";
      aspects = server ++ ["auditd" "impermanence" "sudo"];
      home = false;
    };
    oob = {
      system = "aarch64-linux";
      channel = inputs.nixpkgs-unstable;
      aspects = server;
      home = false;
    };
  };

  mkUnstable = system:
    import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  hardening = import ../_lib/systemd-hardening.nix lib;
  flakePath = "/nix/nixops";

  homeExtra = system: {
    inherit inputs hardening flakePath user;
    nixpkgs-unstable = mkUnstable system;
  };

  # Home base shared by the NixOS-embedded and standalone home configs.
  hmShared = {
    home.username = user.name;
    home.homeDirectory = "/home/${user.name}";
    home.stateVersion = "26.05";
    home.file.".wallpapers" = {
      source = ../../share/wallpapers;
      recursive = true;
    };
    home.sessionVariables.NIX_CONFIG = "experimental-features = nix-command flakes";
    home.sessionVariables.NH_FLAKE = flakePath;
    programs.home-manager.enable = true;
    nixpkgs.config.allowUnfree = true;
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  mkNixos = name: {
    system,
    aspects,
    home ? true,
    channel ? nixpkgs,
  }:
    channel.lib.nixosSystem {
      specialArgs = {inherit inputs hardening user;};
      modules =
        lib.attrVals aspects config.flake.modules.nixos
        ++ ["${self}/hosts/${name}/options.nix"]
        ++ lib.optionals home [
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.users.${user.name}.imports = homeAspects ++ [hmShared];
            home-manager.extraSpecialArgs = homeExtra system;
          }
        ];
    };

  mkHome = {system, ...}:
    home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = homeExtra system;
      modules = homeAspects ++ [hmShared];
    };
in {
  flake.nixosConfigurations = lib.mapAttrs mkNixos hosts;
  flake.homeConfigurations =
    lib.mapAttrs' (name: h: lib.nameValuePair "${user.name}@${name}" (mkHome h))
    (lib.filterAttrs (_: h: h.home or true) hosts);
}
