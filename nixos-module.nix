bmob-server:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  cfg = config.services.bmob-server;
in
{
  options.services.bmob-server = {
    enable = mkEnableOption "Enable the bmob server";
    port = mkOption {
      type = types.port;
      default = 9292;
      description = "The port for the HTTP server";
    };
    address = mkOption {
      type = types.str;
      default = "localhost";
      description = "The address to listen on";
    };
    user = mkOption {
      type = types.str;
      default = "bmob-server";
      description = "The user to run this program under.";
    };
    group = mkOption {
      type = types.str;
      default = "bmob-server";
      description = "The group to run this program under.";
    };
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/bmob-server/";
      description = "The directory for data (mob database, etc)";
    };
    package = mkOption {
      type = types.package;
      default = bmob-server;
      description = "The bmob-server package to use";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0700 ${cfg.user} ${cfg.group} - -"
    ];
    systemd.services.bmob-server = {
      description = "Better MOB Database Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        ExecStart = "${bmob-server}/bin/bmob-server ${cfg.address} ${cfg.port} ${cfg.dataDir}";
      };
    };
    users.users = {
      bmob-server = mkIf (cfg.user == "bmob-server") {
        isSystemUser = true;
        home = cfg.dataDir;
        group = cfg.group;
      };
    };
    users.groups = {
      bmob-server =
        mkIf (cfg.group == "bmob-server")
          {
          };
    };
  };
}
