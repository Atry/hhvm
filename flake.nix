{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    nix-utils.url = "github:juliosueiras-nix/nix-utils";
    nix-utils.inputs.nixpkgs.follows = "nixpkgs";
    nix-utils.inputs.flake-utils.follows = "flake-utils";
  };
  outputs =
    { self, nixpkgs, flake-utils, flake-compat, nix-utils }:
    flake-utils.lib.eachSystem [
      "x86_64-darwin"
      "x86_64-linux"
    ]
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                # A customized libdwarf.nix is provided because the libdwarf
                # package in nixpkgs-unstable does not support macOS yet.
                libdwarf = final.callPackage ./libdwarf.nix { };
              })
            ];
          };
          fpmScript =
            outputType: pkg:
            ''
              # Copy to a temporority directory as a workaround to https://github.com/jordansissel/fpm/issues/807
              while read LINE
              do
                mkdir -p "$(dirname "./$LINE")"
                cp -r "/$LINE" "./$LINE"
                chmod --recursive u+w "./$LINE"
                FPM_INPUTS+=("./$LINE")
              done < ${pkgs.lib.strings.escapeShellArg(pkgs.referencesByPopularity pkg)}

              ${pkgs.lib.strings.escapeShellArg pkgs.fpm}/bin/fpm \
                --package "$out" \
                --input-type dir \
                --output-type ${outputType} \
                --name ${pkgs.lib.strings.escapeShellArg pkg.pname} \
                --version ${pkgs.lib.strings.escapeShellArg pkg.version} \
                --description ${pkgs.lib.strings.escapeShellArg pkg.meta.description} \
                --url ${pkgs.lib.strings.escapeShellArg pkg.meta.homepage} \
                --maintainer ${pkgs.lib.strings.escapeShellArg (pkgs.lib.strings.intersperse ", " (map ({name, email, ...}: "\"${name}\" <${email}>") pkg.meta.maintainers))} \
                --license ${pkgs.lib.strings.escapeShellArg (pkgs.lib.strings.intersperse " AND " (map ({spdxId, ...}: spdxId) (pkgs.lib.lists.toList pkg.meta.license)))} \
                --after-install ${
                  pkgs.writeScript "after-install.sh" ''
                    for EXECUTABLE in ${pkgs.lib.strings.escapeShellArg pkg}/bin/*
                    do
                      NAME=$(basename "$EXECUTABLE")
                      update-alternatives --install "/usr/bin/$NAME" "$NAME" "$EXECUTABLE" 1
                    done
                  ''
                } \
                --before-remove ${
                  pkgs.writeScript "before-remove.sh" ''
                    for EXECUTABLE in ${pkgs.lib.strings.escapeShellArg pkg}/bin/*
                    do
                      NAME=$(basename "$EXECUTABLE")
                      update-alternatives --remove "$NAME" "$EXECUTABLE"
                    done
                  ''
                } \
                -- \
                "''${FPM_INPUTS[@]}"
            '';
        in
        rec {
          packages.hhvm = pkgs.callPackage ./hhvm.nix {
            lastModifiedDate = self.lastModifiedDate;
          };
          packages.default = packages.hhvm;

          checks.quick = pkgs.runCommand
            "hhvm-quick-test"
            {
              buildInputs = pkgs.lib.optionals pkgs.hostPlatform.isMacOS [
                # `system_cmds` provides `sysctl`, which is used in hphp/test/run.php on macOS
                pkgs.darwin.system_cmds
              ];
            }
            ''
              set -ex
              cd ${./.}
              HHVM_BIN="${packages.hhvm}/bin/hhvm" "${packages.hhvm}/bin/hhvm" hphp/test/run.php quick
              mkdir $out
            '';

          devShells.default = pkgs.mkShell ({
            buildInputs = packages.hhvm.nativeBuildInputs ++ packages.hhvm.buildInputs ++ [
              pkgs.rnix-lsp
              pkgs.fpm
              pkgs.rpm
            ];
            NIX_CFLAGS_COMPILE = packages.hhvm.NIX_CFLAGS_COMPILE;
            CMAKE_INIT_CACHE = packages.hhvm.cmakeInitCache;
          });

          bundlers.rpm = pkg: pkgs.runCommand
            "bundle.rpm"
            { nativeBuildInputs = [ pkgs.rpm ]; }
            (fpmScript "rpm" pkg);

          bundlers.deb = pkg: pkgs.runCommand
            "bundle.deb"
            { nativeBuildInputs = [ pkg.stdenv.cc ]; }
            (fpmScript "deb" pkg);

        }
      );
}
