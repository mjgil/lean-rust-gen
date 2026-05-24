use std::{
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

const ALLOW_FALLBACK_ENV: &str = "LEAN_RUST_CORE_ALLOW_FALLBACK";

fn main() {
    println!("cargo:rerun-if-changed=../LeanRustCore");
    println!("cargo:rerun-if-changed=../Main.lean");
    println!("cargo:rerun-if-changed=../lakefile.toml");
    println!("cargo:rerun-if-changed=src/generated.rs");
    println!("cargo:rerun-if-env-changed={ALLOW_FALLBACK_ENV}");
    println!("cargo:rerun-if-env-changed=CI");

    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("Cargo sets OUT_DIR"));
    let generated_out = out_dir.join("generated.rs");
    let manifest_dir =
        PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("Cargo sets CARGO_MANIFEST_DIR"));
    let repo_root = manifest_dir
        .parent()
        .expect("rust crate lives under repo root");
    let lean_workspace_present = repo_root.join("lakefile.toml").exists();

    if !lean_workspace_present {
        println!(
            "cargo:warning=Lean workspace not packaged with crate; using checked-in src/generated.rs for publish/package verification"
        );
        copy_fallback(&manifest_dir, &generated_out);
        return;
    }

    let lean_status = Command::new("lake")
        .args([
            "exe",
            "gen_rust",
            generated_out.to_str().expect("utf-8 OUT_DIR"),
        ])
        .current_dir(repo_root)
        .status();

    match lean_status {
        Ok(status) if status.success() => {
            println!(
                "cargo:warning=Lean extractor produced {}",
                generated_out.display()
            );
        }
        Ok(status) => {
            fail_or_use_development_fallback(
                &manifest_dir,
                &generated_out,
                format!("lake exited with status {status}"),
            );
        }
        Err(err) => {
            fail_or_use_development_fallback(
                &manifest_dir,
                &generated_out,
                format!("lake was not available: {err}"),
            );
        }
    }
}

fn fail_or_use_development_fallback(manifest_dir: &Path, generated_out: &Path, reason: String) {
    if development_fallback_allowed() {
        println!(
            "cargo:warning={reason}; using checked-in src/generated.rs because {ALLOW_FALLBACK_ENV}=1 in a non-release, non-CI build"
        );
        copy_fallback(manifest_dir, generated_out);
        return;
    }

    panic!(
        "Lean generator failed ({reason}). Checked-in generated.rs fallback is disabled unless {ALLOW_FALLBACK_ENV}=1, and it is always disabled for CI or release builds. Run ./scripts/gen.sh or install the pinned Lean toolchain."
    );
}

fn development_fallback_allowed() -> bool {
    let explicit = env::var(ALLOW_FALLBACK_ENV).ok().as_deref() == Some("1");
    let profile = env::var("PROFILE").unwrap_or_default();
    let ci = env::var("CI")
        .map(|value| !value.is_empty() && value != "0" && value != "false")
        .unwrap_or(false);

    explicit && profile != "release" && !ci
}

fn copy_fallback(manifest_dir: &Path, generated_out: &Path) {
    let fallback = manifest_dir.join("src/generated.rs");
    fs::copy(&fallback, generated_out).unwrap_or_else(|err| {
        panic!(
            "failed to copy fallback generated Rust from {} to {}: {err}",
            fallback.display(),
            generated_out.display()
        )
    });
}
