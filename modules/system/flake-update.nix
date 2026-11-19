# @desc: Weekly flake.lock bump for selected inputs; applied on next switch
{...}: {
  flake.modules.nixos.flakeUpdate = {
    config,
    lib,
    user,
    flakePath,
    hardening,
    ...
  }: let
    inputs = ["nixpkgs-firefox" "nixpkgs-kernel" "nixpkgs-unstable"];
  in {
    systemd.services.flake-update = {
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig =
        hardening.sealed
        // {
          Type = "oneshot";
          User = user.name;
          PrivateNetwork = false;
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
          ReadWritePaths = [flakePath];
          RuntimeDirectory = "flake-update";
          Environment = "HOME=%t/flake-update";
          UMask = "0022";
          ExecStart = "${config.nix.package}/bin/nix flake update --flake ${flakePath} ${lib.escapeShellArgs inputs}";
        };
    };
    systemd.timers.flake-update = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
