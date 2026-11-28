{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "baton";
  version = "unstable-2026-11-28";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "c27d78b0fda5873b9f68520abbfc9150338f207c";
    sha256 = "sha256-QlCR3IDsiCpG7fK8F0u/0wkZm50hUqoUAxoo7vYxJCw=";
  };

  cargoHash = "sha256-9sB9yAoNosZ4oul4LBHg724Nmmh4yv8BbvI5ZooSy3E=";

  meta = with lib; {
    description = "Pass a command from a remote shell to allow-listed actions on the local machine";
    homepage = "https://github.com/Urie96/baton";
    license = licenses.mit;
    mainProgram = "baton";
    platforms = platforms.unix;
  };
}
