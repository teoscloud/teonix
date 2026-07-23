{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "hyprflow";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "isorensen";
    repo = "hyprflow";
    rev = "v${version}";
    hash = "sha256-5QWzimuNSl91TLWhBBiq4HCQyYtoSP8c9VknxSA0O8s=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  # Only used at runtime via hyprctl / proc; no Hyprland headers needed.
  doCheck = false;

  meta = with lib; {
    description = "Save and restore Hyprland window sessions";
    homepage = "https://github.com/isorensen/hyprflow";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "hyprflow";
    platforms = platforms.linux;
  };
}
