let
  inherit ((import <nixpkgs> {}).pkgs.haskell-ng.packages.ghc7101.override {
    overrides = self: super: builtins.listToAttrs (map (name: {
        inherit name;
        value = self.callPackage (./. + "/${name}") {};
      }) [ "tetrode-ephys" "arte-lib" "tetrode-graphics" ]);
    }) callPackage;
in path: (callPackage path {}).env