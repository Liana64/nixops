# @desc: veles package, shared by its aspect and the waybar module
pkgs:
pkgs.writeShellApplication {
  name = "veles";
  runtimeInputs = with pkgs; [git gnutar coreutils findutils];
  text = builtins.readFile ../bin/veles;
}
