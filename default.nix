{
  stdenv,
  lib,
  rubyEnv,
  ruby,
}:
let
  inherit (lib.fileset) unions toSource;
in
stdenv.mkDerivation {
  name = "bmob-server";
  version = "0.1";

  src = toSource {
    fileset = unions [
      ./config.ru
      ./bmobserver.rb
      ./Gemfile
      ./Gemfile.lock
      ./views
    ];
    root = ./.;
  };

  buildInputs = [
    rubyEnv
    ruby
  ];

  installPhase = ''
    mkdir -p $out/{bin,share/bmob-server}
    cp -r * $out/share/bmob-server
    bin=$out/bin/bmob-server
    cat >$bin <<EOF
      #!/bin/sh -e
      cd $out/share/bmob-server
      exec ${rubyEnv}/bin/bundle exec ${rubyEnv}/bin/unicorn config.ru \
        -E production -o "$1" -p "$2"
    EOF
    chmod +x $bin
  '';
}
