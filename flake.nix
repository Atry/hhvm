{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };
  outputs =
    { self, nixpkgs, flake-utils, flake-compat }:
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
        in
        rec {
          packages.hhvm = pkgs.callPackage ./hhvm.nix {
            lastModifiedDate = self.lastModifiedDate;
          };
          packages.default = packages.hhvm;

          checks.quick = pkgs.stdenv.mkDerivation {
            name = "hhvm-quick-test";

            buildInputs = [ packages.hhvm ];
            unpackPhase = "true";

            buildPhase = ''
              HHVM_BIN="${packages.hhvm}" "${packages.hhvm}" hphp/test/run.php quick
            '';
            installPhase = "mkdir -p $out";
          };

          devShells.default = pkgs.mkShell ({
            buildInputs = packages.hhvm.nativeBuildInputs ++ packages.hhvm.buildInputs ++ [
              pkgs.rnix-lsp
            ];
            NIX_CFLAGS_COMPILE = packages.hhvm.NIX_CFLAGS_COMPILE;
            CMAKE_INIT_CACHE = packages.hhvm.cmakeInitCache;
          });
        }
      );
}
