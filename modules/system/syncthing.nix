# @desc: Syncthing
{...}: {
  flake.modules.homeManager.syncthing = {
    lib,
    pkgs,
    osConfig,
    hardening,
    inputs,
    ...
  }: let
    sync = inputs.self.syncthing;
    self =
      if osConfig == null
      then "framework"
      else osConfig.networking.hostName;
    folders = lib.filterAttrs (_: f: lib.elem self f.devices) sync.folders;
    peers = lib.remove self (lib.unique (lib.concatMap (f: f.devices) (lib.attrValues folders)));
  in
    lib.mkIf (osConfig.machineSecrets or true) {
      # setLowPriority calls setpriority/ioprio_set (@resources), home read-only
      # with the synced folders and state db carved out
      systemd.user.services.syncthing.Service =
        hardening.confined
        // {
          SystemCallFilter = lib.mkForce ["@system-service" "~@privileged"];
          ProtectHome = "read-only";
          ReadWritePaths = lib.concatStringsSep " " (
            ["%t" "%h/.local/state/syncthing"] ++ lib.mapAttrsToList (_: f: "%h/${f.path}") folders
          );
        };

      services.syncthing = {
        enable = true;
        overrideDevices = true;
        overrideFolders = true;

        guiCredentials = {
          username = "admin";
          passwordFile = "/var/secrets/syncthing/gui-passwd";
        };

        settings = {
          devices = lib.getAttrs peers sync.devices;

          folders =
            lib.mapAttrs (_: f: {
              inherit (f) label;
              path = "~/${f.path}";
              devices = lib.remove self f.devices;
              versioning = f.versioning or sync.versioning;
            })
            folders;

          options = {
            globalAnnounceEnabled = false;
            localAnnounceEnabled = false;
            relaysEnabled = false;
            natEnabled = false;
            urAccepted = -1;
          };
        };
      };

      # SQLite sidecars must never sync — live WAL/shared-memory files tear across
      # peers. taskchampion.sqlite3 itself rides along as a single-writer backup.
      # Real file, not home.file: Syncthing v2 opens .stignore O_NOFOLLOW (ELOOP on symlinks).
      home.activation.syncthingStignore = lib.hm.dag.entryAfter ["writeBoundary"] (''
          run install -Dm644 ${pkgs.writeText "stignore" ''
            *-wal
            *-shm
            *-journal
            *.log
          ''} $HOME/Sync/Data/.stignore
        ''
        + lib.concatStrings (lib.mapAttrsToList (_: f: ''
          run install -Dm644 ${pkgs.writeText "stignore" (lib.concatLines f.ignores)} "$HOME/${f.path}/.stignore"
        '') (lib.filterAttrs (_: f: f ? ignores) folders)));
    };
}
