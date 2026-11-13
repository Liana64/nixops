{
  config,
  pkgs,
  ...
}: {
  jovian.decky-loader.enable = true;

  systemd.tmpfiles.rules = ["L+ /home/deck/retrodeck - - - - ${config.services.syncthing.settings.folders.m6dg2-sze2f.path}"];

  services.flatpak.enable = true;
  systemd.services.retrodeck = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.flatpak];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      flatpak install -y --noninteractive --or-update flathub net.retrodeck.retrodeck
    '';
    serviceConfig.Type = "oneshot";
  };

  environment.systemPackages = with pkgs; [
    (callPackage ../../modules/_pkgs/ac6recomp/package.nix {
      roots = [
        config.systemd.tmpfiles.settings.graphics-driver."/run/opengl-driver"."L+".argument
        config.environment.etc.fonts.source
      ];
      games = config.services.syncthing.settings.folders.todzo-uawzg.path;
    })
    localsend
    pcsx2
    ppsspp
    prismlauncher
    protonplus
    protontricks
  ];
}
