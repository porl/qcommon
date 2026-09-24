{
  description = "qcommon - shared Quickshell components for qshell and qmlgreetd";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # The component tree. Both qshell and qmlgreetd copy it into their own
      # QML root so the components resolve by name (QML's implicit directory
      # import) without a build-time module path.
      qmlTree =
        pkgs:
        pkgs.runCommand "qcommon-qml" { } ''
          mkdir -p $out/share/qcommon
          cp -r ${./qml} $out/share/qcommon/qml
        '';
    in
    {
      packages = forAllSystems (pkgs: {
        default = qmlTree pkgs;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.quickshell ];
        };
      });
    };
}
