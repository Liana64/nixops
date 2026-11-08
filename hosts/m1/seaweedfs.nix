{
  config,
  lib,
  pkgs,
  hardening,
  inputs,
  user,
  ...
}: let
  net = inputs.self.network;
  meta = "/rpool/seaweedfs";
  data = "/tank/cluster/s3";
  weed = "${pkgs.seaweedfs}/bin/weed";

  ports = {
    master = 9333;
    volume = 8080;
    filer = 8888;
    s3 = 8333;
    metrics = 9327;
  };
  internal = lib.concatMap (p: [p (p + 10000)]) [ports.master ports.volume ports.filer];

  identities = {
    admin = ["Admin" "Read" "Write" "List" "Tagging"];
    docs = ["Read:docs" "Write:docs" "List:docs" "Tagging:docs"];
    etcd = ["Write:etcd"];
    matrix = ["Read:matrix" "Write:matrix" "List:matrix" "Tagging:matrix"];
    loki = ["Read:loki" "Write:loki" "List:loki"];
    fluxer = lib.concatMap (b: map (a: "${a}:${b}") ["Read" "Write" "List" "Tagging"]) ["fluxer" "fluxer-uploads" "fluxer-harvests" "fluxer-reports"];
  };
  key = name: k: config.sops.placeholder."seaweedfs/${name}/${k}";

  store = dir:
    pkgs.linkFarm "seaweedfs-store" {
      "filer.toml" = (pkgs.formats.toml {}).generate "filer.toml" {
        leveldb2 = {
          enabled = true;
          inherit dir;
        };
      };
    };

  options = name: attrs: pkgs.writeText "${name}.options" (lib.generators.toKeyValue {} attrs);

  server = options "server" {
    ip = "127.0.0.1";
    "ip.bind" = "127.0.0.1";
    "master.port" = ports.master;
    "volume.port" = ports.volume;
    "filer.port" = ports.filer;
    s3 = true;
    "s3.ip.bind" = net.cluster.hosts.m1;
    "s3.port" = ports.s3;
    "s3.config" = config.sops.templates."seaweedfs-s3.json".path;
    filer = true;
    "master.dir" = "${meta}/master";
    "master.volumeSizeLimitMB" = 1024;
    dir = data;
    "volume.max" = 2000;
    metricsIp = net.cluster.hosts.m1;
    metricsPort = ports.metrics;
  };

  backup = options "meta-backup" {
    filer = "127.0.0.1:${toString ports.filer}";
    config = "${store "${data}/meta"}/filer.toml";
    restart = true;
  };

  unit = after: binds: exec: {
    wantedBy = ["multi-user.target"];
    requires = ["zfs-datasets.service"] ++ after;
    after = ["zfs-datasets.service" "network.target"] ++ after;
    serviceConfig =
      hardening.confined
      // {
        ExecStart = exec;
        User = "seaweedfs";
        Group = "seaweedfs";
        Restart = "on-failure";
        RestartSec = 5;
        TemporaryFileSystem = "/tank /rpool";
        BindPaths = binds;
      };
  };
in {
  motd.commands = [["aws s3 ls" "s3 buckets"]];

  sops = {
    secrets = lib.listToAttrs (lib.concatMap (name:
      map (k: lib.nameValuePair "seaweedfs/${name}/${k}" {}) ["access-key" "secret-key"])
    (lib.attrNames identities));
    templates = {
      "seaweedfs-s3.json" = {
        owner = "seaweedfs";
        restartUnits = ["seaweedfs.service"];
        content = builtins.toJSON {
          identities =
            lib.mapAttrsToList (name: actions: {
              inherit name actions;
              credentials = [
                {
                  accessKey = key name "access-key";
                  secretKey = key name "secret-key";
                }
              ];
            })
            identities;
        };
      };
      aws-credentials = {
        owner = user.name;
        content = ''
          [default]
          aws_access_key_id=${key "admin" "access-key"}
          aws_secret_access_key=${key "admin" "secret-key"}
        '';
      };
    };
  };

  users.users.${user.name}.packages = [
    (pkgs.symlinkJoin {
      name = "awscli2";
      paths = [pkgs.awscli2];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/aws \
          --set AWS_SHARED_CREDENTIALS_FILE ${config.sops.templates.aws-credentials.path} \
          --set AWS_CONFIG_FILE /dev/null \
          --set AWS_ENDPOINT_URL http://${net.cluster.hosts.m1}:${toString ports.s3} \
          --set AWS_REGION us-east-1 \
          --set AWS_EC2_METADATA_DISABLED true
      '';
    })
  ];

  networking.firewall = {
    interfaces.cluster.allowedTCPPorts = [ports.s3 ports.metrics];
    extraCommands = ''
      iptables -w -N seaweedfs-lo 2>/dev/null || iptables -w -F seaweedfs-lo
      iptables -w -A seaweedfs-lo -p tcp --syn -m multiport --dports ${lib.concatMapStringsSep "," toString internal} \
        -m owner ! --uid-owner ${toString config.users.users.seaweedfs.uid} -j REJECT --reject-with tcp-reset
      iptables -w -C OUTPUT -o lo -j seaweedfs-lo 2>/dev/null || iptables -w -A OUTPUT -o lo -j seaweedfs-lo
    '';
  };

  systemd.services = {
    seaweedfs = lib.recursiveUpdate (unit [] [meta data] "${weed} -logtostderr server -options=${server}") {
      preStart = "mkdir -p ${meta}/master ${meta}/filer ${data}/meta";
      serviceConfig.WorkingDirectory = store "${meta}/filer";
    };
    seaweedfs-meta-backup = lib.recursiveUpdate (unit ["seaweedfs.service"] ["${data}/meta"] "${weed} -logtostderr filer.meta.backup -options=${backup}") {
      serviceConfig.Restart = "always";
    };
  };
}
