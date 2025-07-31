// bindings/rust/zrraw-sys/build.rs
use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let zrraw_root = PathBuf::from("../../../");

    // Get the target from Cargo
    let target = env::var("TARGET").unwrap();

    // --- KEY CHANGE: Remove the "-pc" part for Zig ---
    let zig_target_str = target.replace("-pc", "");
    let zig_target_arg = format!("-Dtarget={}", zig_target_str);

    // Build the Zig library
    let output = Command::new("zig")
        // --- KEY CHANGE: Use the corrected target string ---
        .args(&["build", "-Doptimize=ReleaseFast", &zig_target_arg])
        .current_dir(&zrraw_root)
        .output()
        .expect("Failed to build zrraw library. Make sure 'zig' is in PATH");

    if !output.status.success() {
        panic!(
            "Failed to build zrraw library:\n{}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    // Tell cargo where to find the library
    println!("cargo:rustc-link-search=native={}/zig-out/lib", zrraw_root.display());
    println!("cargo:rustc-link-lib=static=zrraw");

    // Generate bindings using the header
    let header_path = zrraw_root.join("zig-out/include/zrraw.h");
    
    let bindings = bindgen::Builder::default()
        .header(header_path.to_str().unwrap())
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate bindings");

    bindings
        .write_to_file(out_dir.join("bindings.rs"))
        .expect("Couldn't write bindings!");

    // Rerun if the header changes
    println!("cargo:rerun-if-changed={}", header_path.display());
}