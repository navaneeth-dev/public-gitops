{
  modulesPath,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  sops.defaultSopsFile = ./secrets/traefik.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  services.traefik = {
    enable = true;

    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          asDefault = true;
          http.redirections.entrypoint = {
            to = "websecure";
            scheme = "https";
          };
        };

        websecure = {
          address = ":443";
          asDefault = true;
          http.tls.certResolver = "letsencrypt-staging";
        };
      };

      # log = {
      #   level = "INFO";
      #   filePath = "${config.services.traefik.dataDir}/traefik.log";
      #   format = "json";
      # };

      certificatesResolvers = {
        # cloudflare.acme = {
        #   email = "certs@rizexor.com";
        #   storage = "${config.services.traefik.dataDir}/acme.json";
        #   dnsChallenge = {
        #     provider = "cloudflare";
        #     resolvers = [
        #       "1.1.1.1:53"
        #       "1.0.0.1:53"
        #     ];
        #   };
        # };

        cloudflare-staging.acme = {
          email = "certs@rizexor.com";
          storage = "${config.services.traefik.dataDir}/acme-staging.json";
          caServer = "https://acme-staging-v02.api.letsencrypt.org/directory";
          dnsChallenge = {
            provider = "cloudflare";
            resolvers = [
              "1.1.1.1:53"
              "1.0.0.1:53"
            ];
          };
        };
      };

      # api.dashboard = false;
      # Access the Traefik dashboard on <Traefik IP>:8080 of your server
      # api.insecure = true;
    };

    dynamicConfigOptions = {
      http = {
        routers = {
          # prod = {
          #   rule = "HostRegexp(`^.+\\.prod\\.rizexor\\.com$`) || Host(`prod.rizexor.com`)";
          #   service = "ingress";
          #   tls = {
          #     certResolver = "cloudflare";
          #     domains = [{
          #       main = "prod.rizexor.com";
          #       sans = [
          #         "*.prod.rizexor.com"
          #         "*.printquick.prod.rizexor.com"
          #       ];
          #     }];
          #   };
          # };

          staging = {
            rule = "HostRegexp(`^.+\\.staging\\.rizexor\\.com$`) || Host(`staging.rizexor.com`)";
            service = "ingress";
            tls = {
              certResolver = "cloudflare-staging";
              domains = [{
                main = "staging.rizexor.com";
                sans = [
                  "*.staging.rizexor.com"
                  "*.printquick.staging.rizexor.com"
                ];
              }];
            };
          };

          # fossindia = {
          #   rule = "HostRegexp(`^.+\\.fossindia\\.ovh$`)";
          #   service = "ingress";
          #   tls = {
          #     certResolver = "cloudflare";
          #     domains = [{
          #       main = "fossindia.ovh";
          #       sans = [
          #         "*.fossindia.ovh"
          #       ];
          #     }];
          #   };
          # };
        };

        services = {
          ingress.loadBalancer.servers = [
            { url = "http://10.0.10.98"; }
            { url = "http://10.0.10.149"; }
            { url = "http://10.0.10.54"; }
          ];
        };
      };
    };
  };

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.neovim
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICiUB1MgFciQ63LsGGBwHVjCtf1cn50BdxN9jTtfTPGF rize@legion"
  ];

  system.stateVersion = "24.05";
}