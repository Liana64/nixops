# @desc: Hardware benchmark tools
_: {
  flake.modules.nixos.perfTools = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      perf
      stress-ng
      fio
    ];
  };
}
