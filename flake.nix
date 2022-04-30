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
              ({
                lib,
                stdenv,
                fetchurl,
                libelf,
                zlib,
                ...
              }: prev: {
                # This overlay is a polyfill of the following PR and can be removed
                # once the PR get merged:
                #   https://github.com/NixOS/nixpkgs/pull/170927
                libdwarf_20210528 = stdenv.mkDerivation rec {
                  pname = "libdwarf";
                  version = "20210528";

                  src = fetchurl {
                    url = "https://www.prevanders.net/libdwarf-${version}.tar.gz";
                    # Upstream displays this hash broken into four parts:
                    sha512 =
                      "e0f9c88554053ee6c1b1333960891189"
                      + "e7820c4a4ddc302b7e63754a4cdcfc2a"
                      + "cb1b4b6083a722d1204a75e994fff340"
                      + "1ecc251b8c3b24090f8cb4046d90f870";
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
            hhvmStdenv =
              if hostPlatform.isLinux
              then gcc10Stdenv
              else llvmPackages_11.stdenv;
          in {
            default = hhvmStdenv.mkDerivation rec {
              pname = "hhvm";
              version = builtins.substring 0 8 self.lastModifiedDate;

              src = ./.;
              nativeBuildInputs =
                [
                  cmake
                  pkg-config
                  flex
                  bison
                  cacert
                  python3
                  patchelf
                  which
                  unixtools.getconf
                ]
                ++ lib.optionals hostPlatform.isLinux [
                  apt # opam will try to execute apt-cache on Ubuntu
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
                  libdwarf_20210528
                ]
                ++ lib.optionals hostPlatform.isLinux [
                  libcap
                  uwimap
                  numactl
                  linux-pam
                ]
                ++ lib.optionals hostPlatform.isMacOS [
                  darwin.apple_sdk.frameworks.CoreFoundation
                  darwin.apple_sdk.frameworks.CoreServices
                ];

              NIX_CFLAGS_COMPILE =
                [
                  "-DFOLLY_MOBILE=0"
                ]
                ++ lib.optionals hostPlatform.isMacOS [
                  # Workaround for dtoa.0.3.2
                  "-Wno-error=unused-command-line-argument"
                ];

              cmakeFlags =
                [
                  "-DHAVE_SYSTEM_TZDATA:BOOL=ON"
                  "-DHAVE_SYSTEM_TZDATA_PREFIX=${tzdata}/share/zoneinfo"
                  "-DMYSQL_UNIX_SOCK_ADDR=/run/mysqld/mysqld.sock"
                  "-DCAN_USE_SYSTEM_ZSTD:BOOL=ON"
                ]
                ++ lib.optionals hostPlatform.isMacOS [
                  "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.15"
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
                # Prebuilt rustc and cargo needs patch if HHVM is built either
                # on NixOS or in a Nix sandbox
                + lib.optionalString hostPlatform.isLinux ''
                  make \
                    -f third-party/rustc/CMakeFiles/bundled_rust.dir/build.make \
                    third-party/rustc/bundled_rust-prefix/src/bundled_rust-stamp/bundled_rust-install
                  patchelf \
                    --set-interpreter ${hhvmStdenv.cc.bintools.dynamicLinker} \
                    --add-needed ${zlib}/lib/libz.so.1 \
                    --add-rpath "${lib.makeLibraryPath [zlib hhvmStdenv.cc.cc.lib]}" \
                    third-party/rustc/bundled_rust-prefix/bin/rustc
                  patchelf \
                    --set-interpreter ${hhvmStdenv.cc.bintools.dynamicLinker} \
                    --add-needed ${zlib}/lib/libz.so.1 \
                    --add-rpath "${lib.makeLibraryPath [zlib hhvmStdenv.cc.cc.lib]}" \
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
