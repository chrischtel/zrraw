// src/root.zig - Corrected version
const std = @import("std");

// === CORE TYPES FOR FFI ===

/// Error codes returned by zrraw functions
pub const ZrRawError = enum(c_int) {
    Success = 0,
    InvalidInput = -1,
    UnsupportedFormat = -2,
    ParseError = -3,
    OutOfMemory = -4,
    IoError = -5,
    CorruptedData = -6,

    pub fn from_zig_error(err: anyerror) ZrRawError {
        return switch (err) {
            error.OutOfMemory => .OutOfMemory,
            error.InvalidInput => .InvalidInput,
            error.UnsupportedFormat => .UnsupportedFormat,
            else => .ParseError,
        };
    }
};

/// Raw image format identifier
pub const ZrRawFormat = enum(c_int) {
    Unknown = 0,
    CR2 = 1, // Canon
    NEF = 2, // Nikon
    ARW = 3, // Sony
    DNG = 4, // Adobe Digital Negative
    RAF = 5, // Fujifilm
    ORF = 6, // Olympus
    RW2 = 7, // Panasonic
    PEF = 8, // Pentax
    X3F = 9, // Sigma
};

/// Image orientation (EXIF standard)
pub const ZrRawOrientation = enum(c_int) {
    Normal = 1,
    FlipH = 2,
    Rotate180 = 3,
    FlipV = 4,
    Transpose = 5,
    Rotate90 = 6,
    Transverse = 7,
    Rotate270 = 8,
};

/// Demosaic algorithm selection
pub const ZrRawDemosaic = enum(c_int) {
    Fast = 0, // Bilinear (speed)
    Quality = 1, // AHD/VNG (quality)
    Best = 2, // LMMSE/AMaZE (best quality)
};

/// Processing parameters
pub const ZrRawProcessParams = extern struct {
    // Demosaicing
    demosaic_algorithm: ZrRawDemosaic = .Quality,

    // White balance (0.0 = auto)
    wb_temperature: f32 = 0.0, // -1.0 to 1.0
    wb_tint: f32 = 0.0, // -1.0 to 1.0

    // Tone mapping
    highlight_recovery: f32 = 0.8, // 0.0 to 1.0
    shadow_lift: f32 = 0.0, // 0.0 to 1.0
    exposure_compensation: f32 = 0.0, // -3.0 to 3.0 stops

    // Output
    output_gamma: f32 = 2.2,
    output_16bit: bool = false, // false = 8bit, true = 16bit
};

/// Camera metadata
pub const ZrRawMetadata = extern struct {
    // Format info
    format: ZrRawFormat,
    width: u32,
    height: u32,
    orientation: ZrRawOrientation,

    // Camera info (null-terminated strings, max 64 chars)
    make: [64]u8,
    model: [64]u8,

    // Capture settings
    iso: u32,
    shutter_speed_num: u32, // Fraction: num/den
    shutter_speed_den: u32,
    aperture_num: u32, // f-number as fraction
    aperture_den: u32,
    focal_length: f32,

    // Color calibration
    color_matrix: [9]f32, // 3x3 camera to XYZ matrix
    white_balance: [3]f32, // RGB multipliers
    black_level: [4]f32, // RGGB black levels
    white_level: [4]u32, // RGGB white levels

    // Internal use
    _reserved: [32]u8,
};

/// Processed image data
pub const ZrRawImage = extern struct {
    width: u32,
    height: u32,
    channels: u32, // 1, 3, or 4
    bits_per_channel: u32, // 8 or 16
    data: ?[*]u8, // Pixel data (managed by zrraw)
    data_size: usize, // Size in bytes

    // Internal use
    _allocator: ?*anyopaque,
    _reserved: [16]u8,
};

// === PUBLIC API FUNCTIONS ===

/// Detect raw format from file header
/// Returns ZrRawError.Success on success
export fn zrraw_detect_format(data: [*]const u8, data_len: usize, format: *ZrRawFormat) ZrRawError {
    detect_format_internal(data[0..data_len], format) catch |err| {
        return ZrRawError.from_zig_error(err);
    };
    return .Success;
}

/// Extract metadata from raw file
/// Returns ZrRawError.Success on success
export fn zrraw_extract_metadata(data: [*]const u8, data_len: usize, metadata: *ZrRawMetadata) ZrRawError {
    extract_metadata_internal(data[0..data_len], metadata) catch |err| {
        return ZrRawError.from_zig_error(err);
    };
    return .Success;
}

/// Process raw file to RGB image
/// Returns ZrRawError.Success on success
export fn zrraw_process_image(
    data: [*]const u8,
    data_len: usize,
    params: *const ZrRawProcessParams,
    result_image: *ZrRawImage,
    result_metadata: *ZrRawMetadata,
) ZrRawError {
    // --- MODIFIED CALL ---
    process_image_internal(data[0..data_len], params, result_image, result_metadata) catch |err| {
        return ZrRawError.from_zig_error(err);
    };
    return .Success;
}

/// Free image data allocated by zrraw
export fn zrraw_free_image(image: *ZrRawImage) void {
    free_image_internal(image);
}

/// Get library version string
export fn zrraw_version() [*:0]const u8 {
    return "zrraw 0.1.0";
}

/// Get supported formats as bit flags
export fn zrraw_supported_formats() u32 {
    return 0xFF; // All formats supported
}

// === INTERNAL IMPLEMENTATIONS ===

const formats = @import("formats/mod.zig");
const processing = @import("processing/mod.zig");

fn detect_format_internal(data: []const u8, format: *ZrRawFormat) !void {
    format.* = try formats.detect(data);
}

fn extract_metadata_internal(data: []const u8, metadata: *ZrRawMetadata) !void {
    // Use 'var' so we can call deinit()
    var parsed = try formats.parse_metadata(data, std.heap.c_allocator);
    // Copy data first
    metadata.* = parsed.to_ffi();
    // THEN deinit. No defer!
    parsed.deinit();
}

fn process_image_internal(
    data: []const u8,
    params: *const ZrRawProcessParams,
    result_image: *ZrRawImage,
    result_metadata: *ZrRawMetadata,
) !void {
    // Use 'var' so we can call deinit()
    var parsed_meta = try formats.parse_metadata(data, std.heap.c_allocator);
    const processed_img = try processing.process_raw(data, params.*);

    // Copy data first
    result_image.* = processed_img.to_ffi();
    result_metadata.* = parsed_meta.to_ffi();

    // THEN deinit.
    parsed_meta.deinit();
}

fn free_image_internal(image: *ZrRawImage) void {
    if (image._allocator) |allocator_ptr| {
        // This now points to the stable c_allocator, so it's safe.
        const allocator = @as(*std.mem.Allocator, @ptrCast(@alignCast(allocator_ptr)));
        if (image.data) |data| {
            allocator.free(data[0..image.data_size]);
        }
    }
    image.* = std.mem.zeroes(ZrRawImage);
}

// === TESTING ===
test "zrraw api" {
    const testing = std.testing;

    // Test format detection
    var format: ZrRawFormat = .Unknown;
    const result = zrraw_detect_format("dummy".ptr, 5, &format);
    try testing.expect(result == .Success);
}
