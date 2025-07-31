// zrraw-sys/build.rs - Dynamic Library Version
use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    let zrraw_root = PathBuf::from("../../../");


    let target = env::var("TARGET").unwrap();
    let zig_target_str = target.replace("-pc", "");
    let zig_target_arg = format!("-Dtarget={}", zig_target_str);

    let output = Command::new("zig")
        .args(&["build", "-Doptimize=ReleaseFast", &zig_target_arg])
        .current_dir(&zrraw_root)
        .output()
        .expect("Failed to build zrraw library.");

    if !output.status.success() {
        panic!(
            "Failed to build zrraw library:\n{}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    // The rest of the script (bindgen) remains to generate the Rust bindings.
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let header_path = zrraw_root.join("zig-out/include/zrraw.h");
    
    let bindings = bindgen::Builder::default()
        .header(header_path.to_str().unwrap())
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate bindings");

    bindings
        .write_to_file(out_dir.join("bindings.rs"))
        .expect("Couldn't write bindings!");

    println!("cargo:rerun-if-changed={}", header_path.display());
}