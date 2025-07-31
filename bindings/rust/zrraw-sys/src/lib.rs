// bindings/rust/zrraw-sys/src/lib.rs
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    #[test]
    fn test_version() {
        unsafe {
            let version_ptr = zrraw_version();
            let version = CStr::from_ptr(version_ptr).to_str().unwrap();
            assert!(version.starts_with("zrraw"));
        }
    }

    #[test]
    fn test_supported_formats() {
        unsafe {
            let formats = zrraw_supported_formats();
            assert!(formats > 0);
        }
    }
}