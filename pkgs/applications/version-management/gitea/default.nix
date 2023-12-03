{ lib
, stdenv
, buildGoModule
, fetchurl
, makeWrapper
, git
, bash
, coreutils
, gitea
, gzip
, openssh
, pam
, sqliteSupport ? true
, pamSupport ? true
, runCommand
, brotli
, xorg
, nixosTests
}:

buildGoModule rec {
  pname = "gitea";
  version = "1.19.4";

  # not fetching directly from the git repo, because that lacks several vendor files for the web UI
  src = fetchurl {
    url = "https://dl.gitea.com/gitea/${version}/gitea-src-${version}.tar.gz";
    hash = "sha256-vNMNEKMpUoVLUGwPPVhLKfElFmjCWgZHY5i1liNs+xk=";
  };

  vendorHash = null;

  patches = [
    ./static-root-path.patch
  ];

  postPatch = ''
    substituteInPlace modules/setting/server.go --subst-var data
  '';

  subPackages = [ "." ];

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = lib.optional pamSupport pam;

  tags = lib.optional pamSupport "pam"
    ++ lib.optionals sqliteSupport [ "sqlite" "sqlite_unlock_notify" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X 'main.Tags=${lib.concatStringsSep " " tags}'"
  ];

  outputs = [ "out" "data" ];

  postInstall = ''
    mkdir $data
    cp -R ./{public,templates,options} $data
    mkdir -p $out
    cp -R ./options/locale $out/locale

    wrapProgram $out/bin/gitea \
      --prefix PATH : ${lib.makeBinPath [ bash coreutils git gzip openssh ]}
  '';

  passthru = {
    data-compressed = runCommand "gitea-data-compressed" {
      nativeBuildInputs = [ brotli xorg.lndir ];
    } ''
      mkdir $out
      lndir ${gitea.data}/ $out/

      # Create static gzip and brotli files
      find -L $out -type f -regextype posix-extended -iregex '.*\.(css|html|js|svg|ttf|txt)' \
        -exec gzip --best --keep --force {} ';' \
        -exec brotli --best --keep --no-copy-stat {} ';'
    '';

    tests = nixosTests.gitea;
  };

  meta = with lib; {
    description = "Git with a cup of tea";
    homepage = "https://gitea.io";
    license = licenses.mit;
    maintainers = with maintainers; [ disassembler kolaente ma27 techknowlogick ];
    broken = stdenv.isDarwin;
    knownVulnerabilities = [
      ''
        Gitea's API and web endpoints before version 1.20.5 are affected by multiple
        critical security vulnerabilities.

        Non-exhaustive list:
         - reveal comments from issues and pull-requests from private repositories
         - delete comments from issues and pull-requests
         - get private release attachments
         - delete releases and tags
         - get ssh deployment keys (public key)
         - get OAuth2 applications (except for the secret)
         - 2FA not being enforced for the container registry login (docker login)

        There isn't a clear way how to backport and validate all those fixes to the now EOL
        Gitea 1.19.x and bumping the release from 1.19.x to 1.20.x is not possible due to
        its breaking nature.
        Given nixpkgs 23.11 has been released by now and nixpkgs 23.05 will reach EOL very
        soon (2023-12-31), please update to nixpkgs 23.11 instead.

        forgejo's blogpost on these issues: https://forgejo.org/2023-11-release-v1-20-5-1/#responsible-disclosure-to-gitea
      ''
    ];
  };
}
