"""Package discovery and local metadata helpers."""

import json
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Package:
    name: str
    method: str  # "nix-update" or "custom"
    path: Path
    extra_args: list[str] | None = None


@dataclass
class UpdateResult:
    package: Package
    success: bool
    changed: bool
    old_version: str | None = None
    new_version: str | None = None


def get_current_version(pkg: Package) -> str | None:
    """Get the version a package currently declares.

    `srcs.json` for update.py-based packages, otherwise the literal
    `version = "...";` in `default.nix` (packages that `inherit (srcs) version`
    are covered by the first branch). Used for commit messages and PR titles.
    """
    srcs_file = pkg.path / "srcs.json"
    if srcs_file.exists():
        try:
            data: dict[str, str] = json.loads(srcs_file.read_text())
            if data.get("version"):
                return data["version"]
        except json.JSONDecodeError:
            pass

    # nix-update packages keep the version in default.nix itself.
    nix_file = pkg.path / "default.nix"
    if nix_file.exists():
        match = re.search(
            r'^\s*version\s*=\s*"([^"]+)"\s*;', nix_file.read_text(), re.MULTILINE
        )
        if match:
            return match.group(1)

    return None


def discover_packages(pkgs_dir: Path) -> list[Package]:
    """Discover all updatable packages."""
    packages: list[Package] = []

    for pkg_dir in pkgs_dir.iterdir():
        if not pkg_dir.is_dir():
            continue

        # Skip the updater package itself
        if pkg_dir.name == "updater":
            continue

        # Check for nix-update-args file
        nix_update_args_file = pkg_dir / "nix-update-args"
        if nix_update_args_file.exists():
            args = nix_update_args_file.read_text().strip().split()
            packages.append(
                Package(
                    name=pkg_dir.name,
                    method="nix-update",
                    path=pkg_dir,
                    extra_args=args,
                )
            )
            continue

        # Check for update.py file
        update_script = pkg_dir / "update.py"
        if update_script.exists():
            packages.append(
                Package(
                    name=pkg_dir.name,
                    method="custom",
                    path=pkg_dir,
                )
            )

    return sorted(packages, key=lambda p: p.name)


def list_packages(packages: list[Package]) -> None:
    """List all discovered packages."""
    print("Packages with nix-update:")
    for pkg in packages:
        if pkg.method == "nix-update":
            args = " ".join(pkg.extra_args or [])
            print(f"  - {pkg.name}" + (f" ({args})" if args else ""))

    print("\nPackages with custom update.py:")
    for pkg in packages:
        if pkg.method == "custom":
            print(f"  - {pkg.name}")
