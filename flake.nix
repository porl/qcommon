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

      checks = forAllSystems (pkgs: {
        # The pure simulation and the mode policy.
        tests = pkgs.runCommand "qcommon-tests" {
          nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
        } ''
          cp -r ${./.} src
          chmod -R u+w src
          cd src
          export HOME=$TMPDIR
          export XDG_CACHE_HOME=$TMPDIR/cache
          export QT_QPA_PLATFORM=offscreen
          export QML2_IMPORT_PATH="${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
          qmltestrunner -input tests
          touch $out
        '';

        # Lint only the components that use nothing but QtQuick (plus the pure
        # JS): Quickshell registers its types from C++ without qmltypes, so
        # qmllint cannot resolve them and would drown real errors in
        # unknown-type noise.
        lint = pkgs.runCommand "qcommon-lint" {
          nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
        } ''
          qmllint ${./qml/Theme.qml} ${./qml/NightSky.qml} ${./qml/MonthGrid.qml} ${./qml/FuzzyMatch.js}
          touch $out
        '';
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.quickshell ];
        };
      });
    };
}
