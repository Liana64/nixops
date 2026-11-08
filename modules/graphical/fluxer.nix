# @desc: Fluxer (AppImage, housed in social)
{...}: {
  flake.modules.homeManager.fluxer = {pkgs, ...}: {
    home.packages = [(pkgs.callPackage ../_pkgs/fluxer/package.nix {})];
  };
}
