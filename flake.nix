rec {
  description = "High-performance JIT compiler for PHP/Hack";

  outputs = {
    self,
    nixpkgs,
  }: rec {
    packages =
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "x86_64-darwin"
      ] (
        system:
          with import nixpkgs {
            inherit system;
            overlays = [
              (self: {
                lib,
                stdenv,
                fetchurl,
                libelf,
                zlib,
                ...
              }: {
                # This overlay is a polyfill of the following PR and can be removed
                # once the PR get merged:
                #   https://github.com/NixOS/nixpkgs/pull/170927
                libdwarf_0_4 = stdenv.mkDerivation rec {
                  pname = "libdwarf";
                  version = "0.4.0";

                  src = fetchurl {
                    url = "https://www.prevanders.net/libdwarf-${version}.tar.xz";
                    # Upstream displays this hash broken into four parts:
                    sha512 =
                      "30e5c6c1fc95aa28a014007a45199160"
                      + "e1d9ba870b196d6f98e6dd21a349e9bb"
                      + "31bba1bd6817f8ef9a89303bed056218"
                      + "2a7d46fcbb36aedded76c2f1e0052e1e";
                  };

                  configureFlags = ["--enable-shared" "--disable-nonshared"];

                  buildInputs = [libelf zlib];

                  meta = {
                    homepage = "https://www.prevanders.net/dwarf.html";
                    platforms = lib.platforms.unix;
                    license = lib.licenses.lgpl21Plus;
                  };
                };
                libdwarf_0_3 = stdenv.mkDerivation rec {
                  pname = "libdwarf";
                  version = "0.3.4";

                  src = fetchurl {
                    url = "https://www.prevanders.net/libdwarf-${version}.tar.xz";
                    # Upstream displays this hash broken into four parts:
                    sha512 =
                      "6957e6c696428b7e59c57e48279528ff"
                      + "602c49ab9833e56a4722f173240eb137"
                      + "3ddd20f5c9dae7c25cc64e6c2131d3b7"
                      + "b5abcf3c12614b88858bdc353a441359";
                  };

                  configureFlags = ["--enable-shared" "--disable-nonshared"];

                  buildInputs = [libelf zlib];

                  meta = {
                    homepage = "https://www.prevanders.net/dwarf.html";
                    platforms = lib.platforms.unix;
                    license = lib.licenses.lgpl21Plus;
                  };
                };
              })
            ];
          }; let
            stdenv = gcc10Stdenv;
          in {
            default = stdenv.mkDerivation rec {
              pname = "hhvm";
              version = builtins.substring 0 8 self.lastModifiedDate;

              src = ./.;
              nativeBuildInputs = [
                cmake
                pkg-config
                flex
                bison
                cacert
                python3
                patchelf
                which
                unixtools.getconf
              ];
              buildInputs =
                [
                  boost
                  libunwind
                  libmemcached
                  pcre
                  gdb
                  git
                  perl
                  libevent
                  gd
                  curl
                  libxml2
                  icu
                  openssl
                  zlib
                  expat
                  oniguruma
                  libmcrypt
                  tbb
                  gperftools
                  bzip2
                  openldap
                  editline
                  libelf
                  glog
                  libpng
                  libxslt
                  libkrb5
                  gmp
                  libedit
                  libvpx
                  imagemagick6
                  fribidi
                  gperf
                  re2c
                  sqlite
                  libgccjit
                  re2
                  tzdata
                  lz4
                  double-conversion
                  brotli
                  libzip
                  zstd
                  jemalloc
                  fmt
                  libsodium
                  unzip
                  freetype
                  gettext
                  libdwarf_0_3
                ]
                ++ lib.optionals hostPlatform.isLinux [
                  libcap
                  uwimap
                  numactl
                  linux-pam
                ];

              cmakeFlags = [
                "-DHAVE_SYSTEM_TZDATA:BOOL=ON"
                "-DHAVE_SYSTEM_TZDATA_PREFIX=${tzdata}/share/zoneinfo"
                "-DMYSQL_UNIX_SOCK_ADDR=/run/mysqld/mysqld.sock"
              ];

              prePatch = ''
                patchShebangs .
              '';

              preBuild =
                ''
                  set -e
                  make \
                    -f third-party/rustc/CMakeFiles/bundled_rust.dir/build.make \
                    third-party/rustc/bundled_rust-prefix/src/bundled_rust-stamp/bundled_rust-patch
                  patchShebangs \
                    third-party/rustc/bundled_rust-prefix/src/bundled_rust
                ''
                # Prebuilt rustc and cargo needs patch if HHVM is built on
                # either NixOS or a Nix sandbox
                + lib.optionalString hostPlatform.isLinux ''
                  make \
                    -f third-party/rustc/CMakeFiles/bundled_rust.dir/build.make \
                    third-party/rustc/bundled_rust-prefix/src/bundled_rust-stamp/bundled_rust-install
                  patchelf \
                    --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
                    --add-needed ${zlib}/lib/libz.so.1 \
                    --add-rpath "${lib.makeLibraryPath [zlib stdenv.cc.cc.lib]}" \
                    third-party/rustc/bundled_rust-prefix/bin/rustc
                  patchelf \
                    --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
                    --add-needed ${zlib}/lib/libz.so.1 \
                    --add-rpath "${lib.makeLibraryPath [zlib stdenv.cc.cc.lib]}" \
                    third-party/rustc/bundled_rust-prefix/bin/cargo
                '';

              meta = {
                inherit description;
                platforms = builtins.attrNames packages;
                homepage = "https://hhvm.com";
                license = "PHP/Zend";
              };
            };
          }
      );
  };
}
