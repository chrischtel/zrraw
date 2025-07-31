// zrraw-sys/build.rs - Hybrid Dynamic Library Model
use std::env;
use std::fs;
use std::io::Cursor;
use std::path::{Path, PathBuf};

fn main() {
    // If the `compile-from-source` feature is enabled, we build the Zig code locally.
    // This is for you, the zrraw developer.
    #[cfg(feature = "compile-from-source")]
    {
        println!("cargo:warning=Building zrraw from source (compile-from-source feature enabled)");
        build_from_source();
    }

    // Otherwise, the default behavior is to download the pre-compiled DLL.
    // This is for RapidRaw contributors.
    #[cfg(not(feature = "compile-from-source"))]
    {
        println!("cargo:warning=Downloading pre-compiled zrraw library");
        download_and_place_dll();
    }

    // Bindgen runs in both cases, as it just needs the header file.
    run_bindgen();
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
fn download_and_place_dll() {
    let target = env::var("TARGET").unwrap();
    let version = "0.1.0"; // IMPORTANT: This must match a real GitHub release tag
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());


    let url = format!(
        "https://github.com/chrischtel/zrraw/releases/download/v{}/zrraw-v{}-{}.zip",
        version, version, target
    );

    // 2. Download the file
    println!("cargo:warning=Downloading zrraw from {}", url);
    let response = ureq::get(&url)
        .call()
        .unwrap_or_else(|e| panic!("Failed to download zrraw library from {}: {:?}", url, e));

    let mut bytes = Vec::new();
    response.into_reader().read_to_end(&mut bytes).unwrap();

    // 3. Unzip the archive
    let mut archive = zip::ZipArchive::new(Cursor::new(bytes)).unwrap();
    let mut dll_file = archive.by_index(0).unwrap(); // Assumes DLL is the first file

    // 4. Find the final destination for the DLL
    //    This is typically `target/debug/` or `target/release/`
    let profile = env::var("PROFILE").unwrap();
    let final_dest_dir = out_dir
        .ancestors()
        .find(|p| p.ends_with(&profile))
        .unwrap()
        .to_path_buf();

    let dll_path = final_dest_dir.join(dll_file.name());
    let mut outfile = fs::File::create(&dll_path).unwrap();
    std::io::copy(&mut dll_file, &mut outfile).unwrap();

    println!("cargo:warning=Placed zrraw.dll at {}", dll_path.display());
}

/// Runs bindgen to generate Rust FFI types from the C header.
fn run_bindgen() {
    let zrraw_root = PathBuf::from("../../../");
    let header_path = zrraw_root.join("zig-out/include/zrraw.h");

    let bindings = bindgen::Builder::default()
        .header(header_path.to_str().unwrap())
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");

    println!("cargo:rerun-if-changed={}", header_path.display());
}