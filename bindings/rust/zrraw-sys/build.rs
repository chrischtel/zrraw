// zrraw-sys/build.rs - FINAL CORRECTED VERSION
use std::env;
use std::fs;
use std::io::{Cursor, Read};
use std::path::PathBuf;

fn main() {
    // This variable will hold the path to the header file, wherever it comes from.
    let header_path: PathBuf;

    #[cfg(feature = "compile-from-source")]
    {
        println!("cargo:warning=Building zrraw from source (compile-from-source feature enabled)");
        build_from_source();
        header_path = PathBuf::from("../../../zig-out/include/zrraw.h");
    }

    #[cfg(not(feature = "compile-from-source"))]
    {
        println!("cargo:warning=Downloading pre-compiled zrraw library");
        // This function will now return the path to the extracted header.
        header_path = download_and_place_dll();
    }

    // Now, run bindgen using the correct header path.
    run_bindgen(&header_path);
}

/// Compiles the local Zig code into a DLL.
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

/// Downloads the DLL from GitHub releases and places it where the executable can find it.
fn download_and_place_dll() -> PathBuf {
    let target = env::var("TARGET").unwrap();
    //TODO: NOT HARDCORE, get from cargo.toml
    let version = "0.1.0";
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    let url = format!(
        "https://github.com/chrischtel/zrraw/releases/download/v{}/zrraw-v{}-{}.zip",
        version, version, target
    );

    println!("cargo:warning=Downloading zrraw from {}", url);
    let response = ureq::get(&url)
        .call()
        .unwrap_or_else(|e| panic!("Failed to download zrraw library from {}: {:?}", url, e));

    // --- THIS IS THE CORRECT API USAGE BASED ON YOUR DOCUMENTATION ---
    // 1. Get the Body from the Response. We ignore the status and headers.
    let (_, body) = response.into_parts();

    // 2. Now, get a reader from the Body and read all bytes into a Vec.
    let mut bytes: Vec<u8> = Vec::new();
    body.into_reader().read_to_end(&mut bytes)
        .unwrap_or_else(|e| panic!("Failed to read response bytes: {:?}", e));

    let mut archive = zip::ZipArchive::new(Cursor::new(bytes)).unwrap();

    // Find the final destination for the DLL
    let profile = env::var("PROFILE").unwrap();
    let final_dest_dir = out_dir.ancestors().find(|p| p.ends_with(&profile)).unwrap();

    // Iterate through the archive to find and extract both files
    for i in 0..archive.len() {
        let mut file = archive.by_index(i).unwrap();
        let file_name = file.name().to_string();

        if file_name.ends_with(".dll") || file_name.ends_with(".so") || file_name.ends_with(".dylib") {
            let dll_path = final_dest_dir.join(&file_name);
            let mut outfile = fs::File::create(&dll_path).unwrap();
            std::io::copy(&mut file, &mut outfile).unwrap();
            println!("cargo:warning=Placed library '{}' at {}", file_name, dll_path.display());
        } else if file_name.ends_with(".h") {
            // Extract the header to the temporary OUT_DIR
            let header_path = out_dir.join(&file_name);
            let mut outfile = fs::File::create(&header_path).unwrap();
            std::io::copy(&mut file, &mut outfile).unwrap();
        }
    }

    // Return the path to the extracted header file for bindgen to use
    out_dir.join("zrraw.h")
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