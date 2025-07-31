// bindings/rust/zrraw/src/lib.rs - CORRECTED VERSION
use image::{DynamicImage, ImageBuffer, Rgb, Rgba};
use std::ffi::CStr;
use thiserror::Error;
use zrraw_sys::*;

#[derive(Error, Debug)]
pub enum ZrRawError {
    #[error("Invalid input data")]
    InvalidInput,
    #[error("Unsupported RAW format")]
    UnsupportedFormat,
    #[error("Parse error: {0}")]
    ParseError(String),
    #[error("Out of memory")]
    OutOfMemory,
    #[error("IO error")]
    IoError,
    #[error("Corrupted data")]
    CorruptedData,
    #[error("Unknown error: {0}")]
    Unknown(i32),
}

impl From<i32> for ZrRawError {
    fn from(code: i32) -> Self {
        match code {
            -1 => ZrRawError::InvalidInput,
            -2 => ZrRawError::UnsupportedFormat,
            -3 => ZrRawError::ParseError("Parse failed".to_string()),
            -4 => ZrRawError::OutOfMemory,
            -5 => ZrRawError::IoError,
            -6 => ZrRawError::CorruptedData,
            other => ZrRawError::Unknown(other),
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum RawFormat {
    Unknown,
    Canon(CanonFormat),
    Nikon(NikonFormat),
    Sony(SonyFormat),
    Adobe(AdobeFormat),
    Fujifilm(FujifilmFormat),
    Olympus(OlympusFormat),
}

#[derive(Debug, Clone, Copy)]
pub enum CanonFormat { CR2 }
#[derive(Debug, Clone, Copy)]
pub enum NikonFormat { NEF }
#[derive(Debug, Clone, Copy)]
pub enum SonyFormat { ARW }
#[derive(Debug, Clone, Copy)]
pub enum AdobeFormat { DNG }
#[derive(Debug, Clone, Copy)]
pub enum FujifilmFormat { RAF }
#[derive(Debug, Clone, Copy)]
pub enum OlympusFormat { ORF }

impl From<ZrRawFormat> for RawFormat {
    fn from(format: ZrRawFormat) -> Self {
        match format {
            1 => RawFormat::Canon(CanonFormat::CR2),
            2 => RawFormat::Nikon(NikonFormat::NEF),
            3 => RawFormat::Sony(SonyFormat::ARW),
            4 => RawFormat::Adobe(AdobeFormat::DNG),
            5 => RawFormat::Fujifilm(FujifilmFormat::RAF),
            6 => RawFormat::Olympus(OlympusFormat::ORF),
            _ => RawFormat::Unknown,
        }
    }
}

#[derive(Debug, Clone)]
pub struct RawMetadata {
    pub format: RawFormat,
    pub width: u32,
    pub height: u32,
    pub orientation: u8,
    pub make: String,
    pub model: String,
    pub iso: u32,
    pub shutter_speed: f32,
    pub aperture: f32,
    pub focal_length: f32,
    pub color_matrix: [f32; 9],
    pub white_balance: [f32; 3],
    pub black_level: [f32; 4],
    pub white_level: [u32; 4],
}

impl From<ZrRawMetadata> for RawMetadata {
    fn from(meta: ZrRawMetadata) -> Self {
        let make = unsafe {
            CStr::from_ptr(meta.make.as_ptr() as *const i8)
                .to_string_lossy()
                .into_owned()
        };
        let model = unsafe {
            CStr::from_ptr(meta.model.as_ptr() as *const i8)
                .to_string_lossy()
                .into_owned()
        };
        let shutter_speed = if meta.shutter_speed_den > 0 {
            meta.shutter_speed_num as f32 / meta.shutter_speed_den as f32
        } else { 0.0 };
        let aperture = if meta.aperture_den > 0 {
            meta.aperture_num as f32 / meta.aperture_den as f32
        } else { 0.0 };

        RawMetadata {
            format: meta.format.into(),
            width: meta.width,
            height: meta.height,
            orientation: meta.orientation as u8,
            make,
            model,
            iso: meta.iso,
            shutter_speed,
            aperture,
            focal_length: meta.focal_length,
            color_matrix: meta.color_matrix,
            white_balance: meta.white_balance,
            black_level: meta.black_level,
            white_level: meta.white_level,
        }
    }
}

#[derive(Default)]
pub struct ProcessingParams {
    pub demosaic_algorithm: DemosaicAlgorithm,
    pub wb_temperature: f32,
    pub wb_tint: f32,
    pub highlight_recovery: f32,
    pub shadow_lift: f32,
    pub exposure_compensation: f32,
    pub output_gamma: f32,
    pub output_16bit: bool,
}

#[derive(Default)]
pub enum DemosaicAlgorithm {
    Fast,
    #[default]
    Quality,
    Best,
}

impl From<ProcessingParams> for ZrRawProcessParams {
    fn from(val: ProcessingParams) -> Self {
        ZrRawProcessParams {
            demosaic_algorithm: match val.demosaic_algorithm {
                DemosaicAlgorithm::Fast => 0,
                DemosaicAlgorithm::Quality => 1,
                DemosaicAlgorithm::Best => 2,
            },
            wb_temperature: val.wb_temperature,
            wb_tint: val.wb_tint,
            highlight_recovery: val.highlight_recovery,
            shadow_lift: val.shadow_lift,
            exposure_compensation: val.exposure_compensation,
            output_gamma: val.output_gamma,
            output_16bit: val.output_16bit,
        }
    }
}

// --- NEW: This struct holds the combined result from the library ---
#[derive(Debug)]
pub struct ProcessedRawFile {
    pub image: DynamicImage,
    pub metadata: RawMetadata,
}

/// Main ZrRaw processor
pub struct ZrRaw;

impl ZrRaw {
    /// Detect the format of a RAW file
    pub fn detect_format(data: &[u8]) -> Result<RawFormat, ZrRawError> {
        let mut format = 0;
        let result = unsafe { zrraw_detect_format(data.as_ptr(), data.len(), &mut format) };
        if result != 0 { return Err(ZrRawError::from(result)); }
        Ok(format.into())
    }

    /// Extract metadata from RAW file
    pub fn extract_metadata(data: &[u8]) -> Result<RawMetadata, ZrRawError> {
        let mut metadata = unsafe { std::mem::zeroed::<ZrRawMetadata>() };
        let result = unsafe { zrraw_extract_metadata(data.as_ptr(), data.len(), &mut metadata) };
        if result != 0 { return Err(ZrRawError::from(result)); }
        Ok(metadata.into())
    }

    // --- MODIFIED: This is the new primary function for processing ---
    /// Process RAW file to an image and extract its metadata in one go.
    pub fn process_file(
        data: &[u8],
        params: ProcessingParams,
    ) -> Result<ProcessedRawFile, ZrRawError> {
        let mut raw_image = unsafe { std::mem::zeroed::<ZrRawImage>() };
        let mut raw_metadata = unsafe { std::mem::zeroed::<ZrRawMetadata>() };
        let ffi_params: ZrRawProcessParams = params.into();

        let result = unsafe {
            zrraw_process_image(
                data.as_ptr(),
                data.len(),
                &ffi_params,
                &mut raw_image,
                &mut raw_metadata,
            )
        };

        if result != 0 {
            return Err(ZrRawError::from(result));
        }

        let dynamic_image = Self::convert_to_dynamic_image(&raw_image)?;
        let metadata: RawMetadata = raw_metadata.into();

        unsafe { zrraw_free_image(&mut raw_image) };

        Ok(ProcessedRawFile {
            image: dynamic_image,
            metadata,
        })
    }

    fn convert_to_dynamic_image(raw_image: &ZrRawImage) -> Result<DynamicImage, ZrRawError> {
        let data_slice = unsafe {
            std::slice::from_raw_parts(raw_image.data, raw_image.data_size)
        };

        match (raw_image.channels, raw_image.bits_per_channel) {
            (3, 8) => {
                ImageBuffer::<Rgb<u8>, _>::from_raw(
                    raw_image.width,
                    raw_image.height,
                    data_slice.to_vec(),
                )
                .map(DynamicImage::ImageRgb8)
                .ok_or(ZrRawError::CorruptedData)
            }
            (4, 8) => {
                ImageBuffer::<Rgba<u8>, _>::from_raw(
                    raw_image.width,
                    raw_image.height,
                    data_slice.to_vec(),
                )
                .map(DynamicImage::ImageRgba8)
                .ok_or(ZrRawError::CorruptedData)
            }
            _ => Err(ZrRawError::UnsupportedFormat),
        }
    }

    /// Get library version
    pub fn version() -> String {
        unsafe { CStr::from_ptr(zrraw_version()).to_string_lossy().into_owned() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        let version = ZrRaw::version();
        assert!(version.starts_with("zrraw"));
    }

    #[test]
    fn test_detect_unknown() {
        let dummy_data = vec![0u8; 100];
        let format = ZrRaw::detect_format(&dummy_data).unwrap();
        assert!(matches!(format, RawFormat::Unknown));
    }

    // --- NEW TEST: Verify the new process_file function ---
    #[test]
    fn test_process_file_stub() {
        let dummy_data = vec![0u8; 100];
        let params = ProcessingParams::default();
        let result = ZrRaw::process_file(&dummy_data, params).unwrap();

        // Check image from stub
        assert_eq!(result.image.width(), 1);
        assert_eq!(result.image.height(), 1);

        // Check metadata from stub
        assert_eq!(result.metadata.make, "Unknown Make");
    }
}