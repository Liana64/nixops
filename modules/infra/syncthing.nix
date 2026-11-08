# @desc: Syncthing device/folder topology shared by clients and m1
{
  config,
  user,
  ...
}: let
  net = config.flake.network;
in {
  flake.syncthing = {
    versioning = {
      type = "trashcan";
      params.cleanoutDays = "90";
    };

    devices = {
      framework.id = "GD6R65V-3NAAPLY-FMWVDMY-AHQGZEK-LZXXMAL-HKLP33W-J6CHSNF-O6BI6AY";
      maxine-framework.id = "WI6FCGN-NBVKCAD-7TC72I4-CFJ7TSA-LKKTXQW-Z22YJES-6CGUKMC-CSQ6LQQ";
      cluster = {
        id = "ENNUNJO-JHR527S-JMMU6IJ-UBA4CL6-CRRPWB4-2GOGD6X-DVIJNJY-DPJLPAR";
        addresses = ["tcp://${net.cluster.hosts.syncthing}:22000"];
      };
      m1 = {
        id = "DZMCSC2-3MUIPEU-SUXQXEH-OYRESED-DWAXB3H-O3ZTUUI-QN4VM4C-ZVUIHAB";
        addresses = ["tcp://${net.hstore.hosts.m1}:22000"];
      };
      catbox = {
        id = "QDLCXGS-IU33KZD-HUE6ZZS-S7XHLD6-MJ5PAGJ-TJ62A7M-SU2JCTU-UDXHDAU";
        addresses = ["tcp://${net.home.hosts.catbox}:22000"];
      };
      steam-deck = {
        id = "L2M4ZBO-G5OB7S3-V6SVJO4-AGXCDBS-PN5PIJR-BEMBFHB-VYYZOHZ-6AIOAA7";
        addresses = ["tcp://${net.home.hosts.steam-deck}:22000"];
      };
    };

    folders = let
      mine = ["m1" "framework" "cluster"];
      maxine = ["m1" "maxine-framework"];
      games = ["m1" "catbox" "steam-deck"];
      history = {
        type = "staggered";
        params.maxAge = toString (90 * 86400);
      };
    in {
      "m6dg2-sze2f" = {
        label = "RetroDECK";
        owner = "games";
        path = "retrodeck";
        devices = games;
        versioning = history;
      };
      "todzo-uawzg" = {
        label = "Ace Combat 6";
        owner = "games";
        path = "games/Ace Combat 6";
        devices = games;
        versioning = history;
      };
      "bddhy-7xeus" = {
        label = "${user.fullName} Projects";
        owner = user.name;
        path = "Projects";
        devices = mine;
        ignores = ["/External"];
      };
      "dqjzb-kwqzh" = {
        label = "${user.fullName} Photos";
        owner = user.name;
        path = "Media/Photos";
        devices = mine;
      };
      "pcem2-vtzke" = {
        label = "${user.fullName} Videos";
        owner = user.name;
        path = "Media/Videos";
        devices = mine;
      };
      "nnbty-vi2es" = {
        label = "${user.fullName} Screenshots";
        owner = user.name;
        path = "Media/Screenshots";
        devices = mine;
      };
      "etaus-cy9u5" = {
        label = "${user.fullName} Notebook";
        owner = user.name;
        path = "Notebook";
        devices = mine;
      };
      "itxfi-cig7x" = {
        label = "Shared Reference";
        owner = "shared";
        path = "Shared/Reference";
        devices = mine;
      };
      "kslaa-vounv" = {
        label = "${user.fullName} Documents";
        owner = user.name;
        path = "Documents";
        devices = mine;
      };
      "z443t-7mcjh" = {
        label = "${user.fullName} Pictures";
        owner = user.name;
        path = "Media/Pictures";
        devices = mine;
      };
      "zd95a-syzmp" = {
        label = "Shared Family";
        owner = "shared";
        path = "Shared/Family";
        devices = mine;
      };
      "grcx4-ny7sk" = {
        label = "Maxine Important Files";
        owner = "maxine";
        path = "Important";
        devices = maxine;
      };
      "vcvl6-co6q6" = {
        label = "Maxine Notebook";
        owner = "maxine";
        path = "Notebook";
        devices = maxine;
      };
    };
  };
}
