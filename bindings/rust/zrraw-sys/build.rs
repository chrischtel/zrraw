// zrraw-sys/build.rs - FINAL OPTIMIZED VERSION
use std::env;
use std::fs;
use std::io::{Cursor, Read};
use std::path::PathBuf;

fn main() {
    // Tell Cargo to re-run this script if it changes.
    println!("cargo:rerun-if-changed=build.rs");
    // Also re-run if the Cargo.toml changes (for version updates)
    println!("cargo:rerun-if-changed=Cargo.toml");

    let header_path: PathBuf;

    #[cfg(feature = "compile-from-source")]
    {
        println!("cargo:warning=Building zrraw from source (compile-from-source feature enabled)");
        build_from_source();
        header_path = PathBuf::from("../../../zig-out/include/zrraw.h");
    }

    #[cfg(not(feature = "compile-from-source"))]
    {
        header_path = download_precompiled_library_if_missing();
    }

    run_bindgen(&header_path);
}


fn download_precompiled_library_if_missing() -> PathBuf {
    let target = env::var("TARGET").unwrap();
    let profile = env::var("PROFILE").unwrap();
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    // 1. Determine the final paths for both the library and the header.
    let lib_name = get_dynamic_lib_name(&target);
    let final_dest_dir = out_dir.ancestors().find(|p| p.ends_with(&profile)).unwrap();
    let final_lib_path = final_dest_dir.join(lib_name);
    let header_path = out_dir.join("zrraw.h");


    if final_lib_path.exists() && header_path.exists() {
        println!("cargo:warning=zrraw library and header are cached. Skipping download.");
        return header_path;
    }

    println!("cargo:warning=zrraw artifacts missing or outdated. Downloading...");
    let archive_bytes = download_archive_bytes(&target);

    // 4. Now, check each file again and place it if it's missing.
    if !final_lib_path.exists() {
        extract_library_from_archive(&archive_bytes, final_dest_dir, lib_name);
    }

    if !header_path.exists() {
        extract_header_from_archive(&archive_bytes, &out_dir);
    }

    header_path
}

/// Downloads the release archive from GitHub and returns its content as bytes.
fn download_archive_bytes(target: &str) -> Vec<u8> {
    // Get version and repository URL from Cargo.toml environment variables.
    // This removes all hardcoded values.
    let version = env!("CARGO_PKG_VERSION");
    let repo_url = env::var("CARGO_PKG_REPOSITORY")
        .expect("CARGO_PKG_REPOSITORY not set in Cargo.toml. Please add a 'repository' key.");

    // Construct the final download URL.
    let download_url = format!(
        "{}/releases/download/v{}/zrraw-v{}-{}.zip",
        repo_url, version, version, target
    );

    println!("cargo:warning=Downloading from {}", download_url);
    let response = ureq::get(&download_url)
        .call()
        .unwrap_or_else(|e| panic!("Failed to download zrraw library from {}: {:?}", download_url, e));

    let (_, body) = response.into_parts();
    let mut bytes = Vec::new();
    body.into_reader()
        .read_to_end(&mut bytes)
        .unwrap_or_else(|e| panic!("Failed to read response bytes: {:?}", e));

    bytes
}

/// Extracts the library file (dll/so/dylib) from the archive bytes to the destination.
fn extract_library_from_archive(bytes: &[u8], dest_dir: &std::path::Path, lib_name: &str) {
    let mut archive = zip::ZipArchive::new(Cursor::new(bytes)).unwrap();
    let mut library_file = archive.by_name(lib_name)
        .unwrap_or_else(|_| panic!("Library file '{}' not found in archive", lib_name));

    let final_lib_path = dest_dir.join(lib_name);
    let mut outfile = fs::File::create(&final_lib_path).unwrap();
    std::io::copy(&mut library_file, &mut outfile).unwrap();
    println!("cargo:warning=Placed library '{}' at {}", lib_name, final_lib_path.display());
}

/// Extracts the header file from the archive bytes to the destination.
fn extract_header_from_archive(bytes: &[u8], dest_dir: &std::path::Path) {
    let mut archive = zip::ZipArchive::new(Cursor::new(bytes)).unwrap();
    let mut header_file = archive.by_name("zrraw.h")
        .expect("Header file 'zrraw.h' not found in archive");

    let header_path = dest_dir.join("zrraw.h");
    let mut outfile = fs::File::create(&header_path).unwrap();
    std::io::copy(&mut header_file, &mut outfile).unwrap();
}

/// Determines the correct name for the dynamic library based on the target triple.
fn get_dynamic_lib_name(target: &str) -> &'static str {
    if target.contains("windows") {
        "zrraw.dll"
    } else if target.contains("apple") {
        "libzrraw.dylib"
    } else {
        "libzrraw.so"
    }
}

/// Compiles the local Zig code.
fn build_from_source() {
    use std::process::Command;
    let zrraw_root = PathBuf::from("../../../");
    let target = env::var("TARGET").unwrap();
    let zig_target_str = target.replace("-pc", "");
    let zig_target_arg = format!("-Dtarget={}", zig_target_str);

    let status = Command::new("zig")
        .args(&["build", "-Doptimize=ReleaseFast", &zig_target_arg])
        .current_dir(&zrraw_root)
        .status()
        .expect("Failed to build zrraw library.");

    if !status.success() {
        panic!("Failed to build zrraw library");
    }
}

/// Runs bindgen to generate Rust FFI types from the C header.
fn run_bindgen(header_path: &PathBuf) {
    if !header_path.exists() {
        panic!("Header file not found at {}", header_path.display());
    }

    println!("cargo:rerun-if-changed={}", header_path.display());

    let bindings = bindgen::Builder::default()
        .header(header_path.to_str().unwrap())
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");
}