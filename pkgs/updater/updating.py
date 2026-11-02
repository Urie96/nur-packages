"""Run the actual update of a package (nix-update or update.py)."""

import importlib.util
import json
import sys
import traceback
from pathlib import Path

from .gitops import git_has_changes, run_cmd
from .package import Package, UpdateResult, get_current_version

# Packages skipped because they do not build on this system.
skipped: set[str] = set()


def get_nix_system() -> str:
    """Get the current Nix system identifier."""
    result = run_cmd(
        ["nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem"],
        check=False,
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return "x86_64-linux"


_cached_system: str | None = None


def current_system() -> str:
    """Get and cache the current Nix system."""
    global _cached_system  # noqa: PLW0603
    if _cached_system is None:
        _cached_system = get_nix_system()
    return _cached_system


# flake root -> {system: attribute names exposed under `packages.<system>`}
_system_maps: dict[str, dict[str, set[str]]] = {}


def flake_systems(flake_root: Path) -> list[str]:
    """List the systems the flake declares (attr names of `legacyPackages`)."""
    result = run_cmd(
        ["nix", "eval", "--json", ".#legacyPackages", "--apply", "builtins.attrNames"],
        cwd=flake_root,
        check=False,
    )
    if result.returncode != 0:
        print(f"Warning: could not read flake systems: {result.stderr.strip()}")
        return [current_system()]
    try:
        return list(json.loads(result.stdout))
    except json.JSONDecodeError:
        return [current_system()]


def available_by_system(flake_root: Path) -> dict[str, set[str]]:
    """Map system -> names exposed by `packages.<system>`.

    `flake.nix` filters `packages` with `meta.availableOn`, so membership in a
    set is exactly "buildable on that system". Attribute names are enough, so
    this stays lazy (no derivations get forced).
    """
    key = str(flake_root)
    if key in _system_maps:
        return _system_maps[key]

    mapping: dict[str, set[str]] = {}
    for system in flake_systems(flake_root):
        result = run_cmd(
            [
                "nix",
                "eval",
                "--json",
                f".#packages.{system}",
                "--apply",
                "builtins.attrNames",
            ],
            cwd=flake_root,
            check=False,
        )
        names: set[str] = set()
        if result.returncode == 0:
            try:
                names = set(json.loads(result.stdout))
            except json.JSONDecodeError:
                pass
        mapping[system] = names

    _system_maps[key] = mapping
    return mapping


def publish_system(pkg_name: str, flake_root: Path) -> str | None:
    """System whose `packages.<system>` exposes pkg_name (current system first).

    Returns None when the name is not a plain derivation anywhere in the flake
    (e.g. `piExtensions` is an attribute set).
    """
    mapping = available_by_system(flake_root)
    current = current_system()
    if pkg_name in mapping.get(current, ()):
        return current
    for system, names in mapping.items():
        if pkg_name in names:
            return system
    return None


def check_available(pkg: Package, flake_root: Path) -> bool:
    """Return False (and explain why) if pkg cannot be built on this system."""
    target = publish_system(pkg.name, flake_root)
    current = current_system()
    if target is None or target == current:
        return True
    print(f"  Skipping: only available for {target}, not {current}")
    skipped.add(pkg.name)
    return False


def no_builder_for_target(stderr: str) -> bool:
    """Whether Nix refused to build because a builder for the drv's system is
    missing, as opposed to a real build failure.

    `nix-update` fetches the new hash by building the fixed-output `src`
    derivation for the package's system and parsing the hash mismatch error.
    Without a builder for that system Nix aborts before starting anything:

        error: a 'aarch64-darwin' with features {} is required to build
        '/nix/store/....drv', but I am a 'x86_64-linux' with features {...}

    Older Nix versions used "Cannot build ... platform mismatch".
    """
    if "platform mismatch" in stderr:
        return True
    return "is required to build" in stderr and "but I am a" in stderr


def run_nix_update(
    pkg: Package,
    flake_root: Path,
    dry_run: bool = False,
    check_system: bool = True,
) -> bool:
    """Run nix-update for a package."""
    current = current_system()

    if check_system and not check_available(pkg, flake_root):
        return True  # Not a failure, just not applicable

    # Update through the attribute that actually exists: darwin-only packages
    # are not in `packages.x86_64-linux`, so use `packages.aarch64-darwin`.
    target = publish_system(pkg.name, flake_root) or current

    if target != current:
        # The hash is obtained by building the fixed-output src derivation, so
        # nix-update needs Nix to be able to build for `target`. A configured
        # remote builder (e.g. an aarch64-darwin machine in nix.buildMachines)
        # makes that work from here; without one the run is a no-op (detected
        # below from stderr) instead of a failure.
        print(
            f"  {pkg.name} is only available for {target}, trying a builder for {target}"
        )

    cmd = [
        "nix-update",
        "--flake",
        f"packages.{target}.{pkg.name}",
    ]

    if pkg.extra_args:
        cmd.extend(pkg.extra_args)

    print(f"  Running: {' '.join(cmd)}")

    if dry_run:
        print("  (dry-run, skipping)")
        return True

    result = run_cmd(cmd, cwd=flake_root, check=False)

    if result.returncode != 0:
        if target != current and no_builder_for_target(result.stderr):
            print(
                f"  Skipping: no {target} builder configured "
                "(add one to nix.buildMachines to update it from here)"
            )
            skipped.add(pkg.name)
            return True
        print(f"  Error: {result.stderr}")
        return False

    if result.stdout:
        print(f"  {result.stdout.strip()}")

    return True


def run_custom_update(
    pkg: Package,
    flake_root: Path,
    dry_run: bool = False,
    check_system: bool = True,
) -> bool:
    """Import and run main() from update.py."""
    if check_system and not check_available(pkg, flake_root):
        return True  # Not a failure, just not applicable

    update_script = pkg.path / "update.py"

    print(f"  Running: {update_script}")

    if dry_run:
        print("  (dry-run, skipping)")
        return True

    spec = importlib.util.spec_from_file_location(f"update_{pkg.name}", update_script)
    if spec is None or spec.loader is None:
        print(f"  Error: Could not load {update_script}")
        return False

    module = importlib.util.module_from_spec(spec)
    sys.modules[f"update_{pkg.name}"] = module
    spec.loader.exec_module(module)

    if not hasattr(module, "main"):
        print(f"  Error: {update_script} has no main() function")
        return False

    # A single broken update.py must not abort the whole run (the other
    # packages still deserve their PR). `sys.exit()` raises SystemExit, which is
    # a BaseException, so it needs its own handler — every update.py in this repo
    # ends with sys.exit(1) on failure.
    try:
        module.main()
    except SystemExit as exc:
        code = exc.code if isinstance(exc.code, int) else 1
        if code == 0:
            return True
        print(f"  Error: {pkg.name}/update.py exited with {code}")
        return False
    except Exception:  # noqa: BLE001 - third-party script boundary
        traceback.print_exc()
        print(f"  Error: {pkg.name}/update.py raised")
        return False

    return True


def update_package(
    pkg: Package,
    flake_root: Path,
    dry_run: bool = False,
    check_system: bool = True,
) -> UpdateResult:
    """Update a single package and return the result."""
    print(f"\nUpdating {pkg.name} (method: {pkg.method})...")

    old_version = get_current_version(pkg)

    # Check for existing changes before update
    had_changes_before = git_has_changes(flake_root)

    if pkg.method == "nix-update":
        success = run_nix_update(pkg, flake_root, dry_run, check_system)
    elif pkg.method == "custom":
        success = run_custom_update(pkg, flake_root, dry_run, check_system)
    else:
        print(f"  Error: Unknown method: {pkg.method}")
        success = False

    new_version = get_current_version(pkg)
    changed = not had_changes_before and git_has_changes(flake_root)

    return UpdateResult(
        package=pkg,
        success=success,
        changed=changed,
        old_version=old_version,
        new_version=new_version,
    )
