# @desc: transmit change sets between nix houses
{...}: {
  flake.modules.homeManager.veles = {pkgs, ...}: {
    home.packages = [(import ../_lib/veles.nix pkgs)];
  };
}
