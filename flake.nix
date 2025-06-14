{
  description = "froyo-choo-choo - a rails starting environment in nix";

  inputs = {
    bundix = {
      url = "github:inscapist/bundix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ruby-nix.url = "github:inscapist/ruby-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ruby-nix, bundix, ... }:
    with flake-utils.lib;
    eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        rn = ruby-nix.lib pkgs;
        gemset = if builtins.pathExists ./gemset.nix then import ./gemset.nix else { };
        ruby = pkgs.ruby_3_4;

        # Running bundix would regenerate `gemset.nix`
        bundix-cli = bundix.packages.${system}.default;

        bundle-add = pkgs.writeShellScriptBin "bundle-add" ''
          set -euo pipefail
          export BUNDLE_PATH=vendor/bundle
          bundle add "$@" --skip-install
        '';

        bundle-lock = pkgs.writeShellScriptBin "bundle-lock" ''
          set -euo pipefail

          export BUNDLE_PATH=vendor/bundle
          bundle lock
        '';

        bundle-update = pkgs.writeShellScriptBin "bundle-update" ''
          set -euo pipefail

          export BUNDLE_PATH=vendor/bundle
          bundle lock --update
        '';

        gemset-update = pkgs.writeShellScriptBin "gemset-update" ''
          set -euo pipefail

          export BUNDLE_PATH=vendor/bundle
          ${bundix}/bin/bundix -l
        '';

        add-gem = pkgs.writeShellScriptBin "add-gem" ''
          set -euo pipefail
          bundle-add "$@"
          gemset-update
        '';

        update-gems = pkgs.writeShellScriptBin "update-gems" ''
          set -euo pipefail
          bundle-update
          gemset-update
        '';
      in
      rec {
        inherit (rn {
            inherit gemset ruby;
            name = "plamotrack";
            gemConfig = pkgs.defaultGemConfig;
        }) env;

        devShells = rec {
          default = dev;
          dev = pkgs.mkShell {
            buildInputs = [
              env
              bundix-cli
              add-gem
              update-gems
              bundle-add
              bundle-lock
              bundle-update
              gemset-update
              pkgs.docker
              pkgs.git
              pkgs.gnumake
              pkgs.nixpkgs-fmt
              pkgs.nodejs
              pkgs.nodePackages.pnpm
              pkgs.postgresql
            ];

            shellHook = ''
              export PGDATA="$PWD/.postgres"
              export PGHOST="$PGDATA"

              if [ ! -d "$PGDATA" ]; then
                echo "Initializing PostgreSQL database in $PGDATA..."
                initdb --auth=trust --no-locale --encoding=UTF8
              fi

              if ! pg_ctl status > /dev/null 2>&1; then
                echo "Starting PostgreSQL server..."
                # Using only unix sockets, and explicitly disabling TCP/IP allows this to run without conflicting
                # with any other apps or worktrees for the sme app
                pg_ctl start -l "$PGDATA/postgresql.log" -o "--unix_socket_directories='$PGDATA' -c listen_addresses='''"
              else
                echo "PostgreSQL server is already running"
              fi
            '';
          };
        };
      }
    );
}
