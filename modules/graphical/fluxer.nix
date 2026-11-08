# @desc: Fluxer (AppImage, housed in social)
{...}: let
  fluxer = pkgs: pkgs.callPackage ../_pkgs/fluxer/package.nix {};
in {
  perSystem = {pkgs, ...}: {
    packages.fluxer = fluxer pkgs;
  };

  flake.modules.homeManager.fluxer = {pkgs, ...}: {
    home.packages = [(fluxer pkgs)];
  };
}
