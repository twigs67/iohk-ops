{ config, lib, pkgs, ... }:

with lib;

let
  ## isPath :: String -> Bool
  isPath = x: !(isAttrs x || isList x || isFunction x || isString x || isInt x || isBool x || isNull x)
               || (isString x && builtins.substring 0 1 x == "/");

  cfg = config.services.buildkite-agent;
in

{
  options = {
    services.buildkite-agent = {
      enable = mkEnableOption "buildkite-agent";

      tokenPath = mkOption {
        type = types.path;
        description = ''
          The token from your Buildkite "Agents" page.

          A path to the token file.
        '';
      };

      name = mkOption {
        type = types.str;
        description = ''
          The name of the agent.
        '';
      };

      meta-data = mkOption {
        type = types.str;
        default = "";
        description = ''
          Meta data for the agent.
        '';
      };

      openssh =
        { privateKeyPath = mkOption {
            type = types.path;
            description = ''
              Private agent key.

              A path to the token file.
            '';
          };
          publicKeyPath = mkOption {
            type = types.path;
            description = ''
              Public agent key.

              A path to the token file.
            '';
          };
        };
    };
  };

  config = mkIf config.services.buildkite-agent.enable {
    users.extraUsers.buildkite-agent =
      { name = "buildkite-agent";
        home = "/var/lib/buildkite-agent";
        createHome = true;
        description = "Buildkite agent user";
        extraGroups = [ "keys" ];
      };

    environment.systemPackages = [ pkgs.buildkite-agent ];

    systemd.services.buildkite-agent =
      let copy = x: target: perms:
                 "cp -f ${x} ${target}; ${pkgs.coreutils}/bin/chmod ${toString perms} ${target}; ";
      in
      { description = "Buildkite Agent";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment.HOME = "/var/lib/buildkite-agent";
        preStart = ''
            ${pkgs.coreutils}/bin/mkdir -m 0700 -p /var/lib/buildkite-agent/.ssh
            ${copy cfg.openssh.privateKeyPath "/var/lib/buildkite-agent/.ssh/id_rsa"     600}
            ${copy cfg.openssh.publicKeyPath  "/var/lib/buildkite-agent/.ssh/id_rsa.pub" 600}

            cat > "/var/lib/buildkite-agent/buildkite-agent.cfg" <<EOF
            token="$(cat ${toString cfg.tokenPath})"
            name="${cfg.name}"
            meta-data="${cfg.meta-data}"
            hooks-path="${pkgs.buildkite-agent}/share/hooks"
            build-path="/var/lib/buildkite-agent/builds"
            bootstrap-script="${pkgs.buildkite-agent}/share/bootstrap.sh"
            EOF
          '';

        serviceConfig =
          { ExecStart = "${pkgs.buildkite-agent}/bin/buildkite-agent start --config /var/lib/buildkite-agent/buildkite-agent.cfg";
            User = "buildkite-agent";
            RestartSec = 5;
            Restart = "on-failure";
            TimeoutSec = 10;
          };
      };
  };
}
