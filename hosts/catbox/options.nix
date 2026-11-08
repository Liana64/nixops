# Ryzen 7 9800X3D, Radeon RX 7900 XT, Gigabyte B850 Gaming X WiFi6E
{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  inherit (inputs.self.network) cluster clients;
  set = lib.concatStringsSep ", ";
in {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.jovian.nixosModules.default
    ./disko.nix
    ./games.nix
    ./media.nix
    ./streaming.nix
    ./syncthing.nix
  ];

  networking.hostName = "catbox";
  motd = {
    description = "living-room console and media client";
    commands = [
      ["sudo systemctl restart display-manager" "restart TV session"]
      (with config.services.prometheus.exporters; [":${toString node.port} :${toString smartctl.port}" "node · smartctl exporters"])
    ];
  };
  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.config.allowUnfree = true;

  boot = {
    loader.systemd-boot = {
      enable = true;
      editor = false;
    };
    loader.efi.canTouchEfiVariables = true;
    loader.timeout = 0;
    consoleLogLevel = 3;
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = ["quiet" "udev.log_level=3" "rd.systemd.show_status=auto" "preempt=full"];
    initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid"];
    kernelModules = ["kvm-amd"];
    kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.page-cluster" = 0;
    };
  };

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;

  jovian = {
    steam = {
      enable = true;
      autoStart = true;
      user = "home";
    };
    hardware.has.amd.gpu = true;
  };
  systemd.services.display-manager = {
    wants = ["network-online.target"];
    after = ["network-online.target"];
  };
  systemd.user.services.gamescope-session.serviceConfig.UnsetEnvironment = ["WAYLAND_DISPLAY" "DISPLAY"];
  networking.modemmanager.enable = false;
  services.orca.enable = false;
  systemd.user.services.orca.enable = false;

  users.users = {
    ${user.name}.openssh.authorizedKeys.keys = inputs.self.keys.${user.name};
    home = {
      isNormalUser = true;
      hashedPassword = "";
    };
    maxine = {
      isNormalUser = true;
      uid = 1002;
      hashedPasswordFile = config.sops.secrets."users/maxine/password".path;
      openssh.authorizedKeys.keys = [inputs.self.keys.maxine];
    };
  };
  sops.secrets."users/maxine/password".neededForUsers = true;

  services.openssh = {
    enable = true;
    settings.AllowUsers = [user.name "maxine"];
  };
  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = ["systemd"];
    };
    smartctl.enable = true;
  };

  networking.firewall.extraInputRules = ''
    ip saddr { ${set clients.${user.name}} } tcp dport 22 accept
    ip saddr { ${set cluster.nodes} } tcp dport { 9100, 9633 } accept
  '';

  zramSwap.enable = true;
  systemd.services.scx.wantedBy = lib.mkOverride 49 ["multi-user.target"];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.11";
}
