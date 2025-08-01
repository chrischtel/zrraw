// bindings/rust/zrraw-sys/src/lib.rs
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bindings_generated() {
        // This test just ensures that the bindings were generated successfully
        // and that the types are available. We don't reference the actual functions
        // since they require dynamic loading which is handled by the high-level crate.
        
        // Test that we can create instances of the structs
        let _metadata: ZrRawMetadata = unsafe { std::mem::zeroed() };
        let _image: ZrRawImage = unsafe { std::mem::zeroed() };
        let _params: ZrRawProcessParams = unsafe { std::mem::zeroed() };
        
        // Test that constants are available
        let _format: ZrRawFormat = 0;
        
        // Test struct sizes to ensure they're properly defined
        assert!(std::mem::size_of::<ZrRawMetadata>() > 0);
        assert!(std::mem::size_of::<ZrRawImage>() > 0);
        assert!(std::mem::size_of::<ZrRawProcessParams>() > 0);
        
        // If we get here, the bindings were generated successfully
    }
}