{ callPackage
, llvmPackages_14
}:
lastModifiedDate:
let
  common = callPackage ./common.nix { } lastModifiedDate;
in
llvmPackages_14.libcxxStdenv.mkDerivation (common // {
  # buildInputs = common.buildInputs ++ [
  #   llvmPackages_13.libcxx
  #   llvmPackages_13.libcxxabi
  # ];
  # nativeBuildInputs = common.nativeBuildInputs ++ [
  #   llvmPackages_13.libcxx.dev
  #   llvmPackages_13.libcxxabi.dev
  # ];
  # cmakeFlags = common.cmakeFlags ++ [
  #   "-DCMAKE_CXX_FLAGS=-stdlib=libc++"
  # ];
  # LD_LIBRARY_PATH
})
