use std::{env, fs, path::PathBuf, process::Command};

fn main() {
    println!("cargo:rerun-if-changed=../LeanRustCore");
    println!("cargo:rerun-if-changed=../Main.lean");
    println!("cargo:rerun-if-changed=../lakefile.toml");
    println!("cargo:rerun-if-changed=src/generated.rs");

    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("Cargo sets OUT_DIR"));
    let generated_out = out_dir.join("generated.rs");
    let manifest_dir =
        PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("Cargo sets CARGO_MANIFEST_DIR"));
    let repo_root = manifest_dir
        .parent()
        .expect("rust crate lives under repo root");

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
            println!("cargo:warning=lake exited with status {status}; using checked-in fallback src/generated.rs");
            copy_fallback(&manifest_dir, &generated_out);
        }
        Err(err) => {
            println!("cargo:warning=lake not available ({err}); using checked-in fallback src/generated.rs");
            copy_fallback(&manifest_dir, &generated_out);
        }
    }
}

fn copy_fallback(manifest_dir: &PathBuf, generated_out: &PathBuf) {
    let fallback = manifest_dir.join("src/generated.rs");
    fs::copy(&fallback, generated_out).unwrap_or_else(|err| {
        panic!(
            "failed to copy fallback generated Rust from {} to {}: {err}",
            fallback.display(),
            generated_out.display()
        )
    });
}
