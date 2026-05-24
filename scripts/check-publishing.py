#!/usr/bin/env python3
"""Validate publishing/versioning metadata for workspace crates."""
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parents[1]
REPO_URL = "https://github.com/mjgil/lean-rust-gen"
VERSION = "0.2.0"

CRATES = [
    ("lean-rust-core-generated", "rust/Cargo.toml", "rust/README.md"),
    ("lean-rust-core-runtime", "crates/runtime/Cargo.toml", "crates/runtime/README.md"),
    ("lean-rust-core-abi", "crates/abi/Cargo.toml", "crates/abi/README.md"),
    ("lean-rust-core-validate", "crates/validate/Cargo.toml", "crates/validate/README.md"),
    ("lean-rust-core-headers", "crates/headers/Cargo.toml", "crates/headers/README.md"),
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def read(path: str) -> str:
    return (ROOT / path).read_text()


def load_toml(path: str) -> dict:
    with (ROOT / path).open("rb") as handle:
        return tomllib.load(handle)


def cargo_metadata() -> dict:
    proc = subprocess.run(
        ["cargo", "metadata", "--format-version", "1", "--locked"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(proc.returncode == 0, proc.stderr.strip() or "cargo metadata failed")
    return json.loads(proc.stdout)


def check_manifests() -> None:
    for package_name, manifest_path, _readme_path in CRATES:
        package = load_toml(manifest_path)["package"]
        require(package["name"] == package_name, f"{manifest_path} has wrong package name")
        require(package["version"] == VERSION, f"{manifest_path} has wrong version")
        require(package["rust-version"] == "1.85", f"{manifest_path} missing rust-version 1.85")
        require(package["license"] == "MIT OR Apache-2.0", f"{manifest_path} missing dual license")
        require(package["repository"] == REPO_URL, f"{manifest_path} missing repository")
        require(package["homepage"] == REPO_URL, f"{manifest_path} missing homepage")
        require(package["documentation"].startswith("https://docs.rs/"), f"{manifest_path} missing docs.rs documentation")
        require(package["readme"] == "README.md", f"{manifest_path} must use local README.md")
        require(package["description"], f"{manifest_path} missing description")
        require(len(package.get("keywords", [])) >= 3, f"{manifest_path} missing keywords")
        require(len(package.get("categories", [])) >= 1, f"{manifest_path} missing categories")
        metadata = load_toml(manifest_path).get("package", {}).get("metadata", {})
        docs_rs = metadata.get("docs", {}).get("rs", {})
        require(docs_rs.get("all-features") is True, f"{manifest_path} missing docs.rs all-features")

    generated = load_toml("rust/Cargo.toml")
    for section, dep_name in [
        ("dependencies", "lean-rust-core-runtime"),
        ("dependencies", "lean-rust-core-abi"),
        ("dev-dependencies", "lean-rust-core-validate"),
    ]:
        dep = generated[section][dep_name]
        require(dep["version"] == VERSION, f"rust/Cargo.toml missing versioned dependency {dep_name}")
        require("path" in dep, f"rust/Cargo.toml missing path dependency {dep_name}")


def check_docs() -> None:
    publishing = read("docs/PUBLISHING.md")
    for needle in [
        "python3 scripts/check-publishing.py",
        "./scripts/check-publishing.sh",
        "cargo doc --workspace --no-deps",
        "cargo tree --workspace",
        "cargo publish --dry-run -p lean-rust-core-generated",
        "repository",
        "homepage",
        "keywords",
        "categories",
        "Unreleased",
    ]:
        require(needle in publishing or needle in read("CHANGELOG.md"), f"missing publishing documentation {needle}")

    for _package_name, _manifest_path, readme_path in CRATES:
        text = read(readme_path)
        require("semver" in text.lower(), f"{readme_path} missing semver policy")
        require("scripts/check-publishing.sh" in text, f"{readme_path} missing publishing gate reference")
        require("docs.rs" in text, f"{readme_path} missing docs.rs reference")

    build_rs = read("rust/build.rs")
    require("Lean workspace not packaged with crate" in build_rs, "rust/build.rs missing packaged-crate fallback")
    require("using checked-in src/generated.rs" in build_rs, "rust/build.rs missing packaged generated.rs fallback")


def check_changelog() -> None:
    changelog = read("CHANGELOG.md")
    require(re.search(r"^## Unreleased$", changelog, re.MULTILINE), "CHANGELOG.md missing Unreleased section")
    require(re.search(rf"^## {re.escape(VERSION)}$", changelog, re.MULTILINE), "CHANGELOG.md missing current version section")
    require("publishing" in changelog.lower(), "CHANGELOG.md missing publishing entry")


def check_dependency_licenses() -> None:
    metadata = cargo_metadata()
    workspace_manifest_paths = {
        str((ROOT / member / "Cargo.toml").resolve())
        for member in ["rust", "crates/runtime", "crates/abi", "crates/validate", "crates/headers"]
    }
    workspace_names = {
        pkg["name"]
        for pkg in metadata["packages"]
        if pathlib.Path(pkg.get("manifest_path", "")).resolve().as_posix() in workspace_manifest_paths
    }
    for package in metadata["packages"]:
        if package["name"] in workspace_names:
            continue
        if not package.get("source"):
            continue
        has_license = bool(package.get("license") or package.get("license_file"))
        require(has_license, f"dependency {package['name']}@{package['version']} is missing license metadata")


def main() -> None:
    check_manifests()
    check_docs()
    check_changelog()
    check_dependency_licenses()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
