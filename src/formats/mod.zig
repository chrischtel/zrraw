// src/formats/mod.zig - CORRECTED VERSION
const std = @import("std");
const root = @import("../root.zig");

// Import format-specific modules
const rw2 = @import("rw2.zig");

pub const FormatError = error{
    UnsupportedFormat,
    InvalidHeader,
    CorruptedData,
    TruncatedFile,
};

pub const RawMetadata = struct {
    format: root.ZrRawFormat,
    width: u32,
    height: u32,
    orientation: root.ZrRawOrientation = .Normal,
    make: []const u8,
    model: []const u8,
    iso: u32,
    shutter_speed: f32,
    aperture: f32,
    focal_length: f32,
    color_matrix: [9]f32,
    white_balance: [3]f32,
    black_level: [4]f32,
    white_level: [4]u32,
    raw_data_offset: u32,
    raw_data_size: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *RawMetadata) void {
        self.allocator.free(self.make);
        self.allocator.free(self.model);
    }

    // --- THIS FUNCTION IS NOW CORRECT ---
    // It safely copies the string data into the FFI struct's fixed-size arrays.
    pub fn to_ffi(self: RawMetadata) root.ZrRawMetadata {
        var ffi_meta = std.mem.zeroes(root.ZrRawMetadata);
        ffi_meta.format = self.format;
        ffi_meta.width = self.width;
        ffi_meta.height = self.height;
        ffi_meta.orientation = self.orientation;
        ffi_meta.iso = self.iso;
        ffi_meta.focal_length = self.focal_length;

        // Copy strings, ensuring null termination.
        const make_len = @min(self.make.len, ffi_meta.make.len - 1);
        @memcpy(ffi_meta.make[0..make_len], self.make[0..make_len]);
        ffi_meta.make[make_len] = 0; // Null terminator

        const model_len = @min(self.model.len, ffi_meta.model.len - 1);
        @memcpy(ffi_meta.model[0..model_len], self.model[0..model_len]);
        ffi_meta.model[model_len] = 0; // Null terminator

        return ffi_meta;
    }
};

// Stub implementations
pub fn detect(data: []const u8) !root.ZrRawFormat {
    // Check for RW2 format first
    if (rw2.detect(data)) {
        return .RW2;
    }

    // TODO: Add other format detections here
    // if (cr2.detect(data)) return .CR2;
    // if (nef.detect(data)) return .NEF;
    // etc.

    return .Unknown;
}

pub fn parse_metadata(data: []const u8, allocator: std.mem.Allocator) !RawMetadata {
    // Detect format first
    const format = try detect(data);

    // Parse based on detected format
    switch (format) {
        .RW2 => return rw2.parse_metadata(data, allocator),
        .Unknown => {
            // Return stub metadata for unknown formats
            return RawMetadata{
                .format = .Unknown,
                .width = 0,
                .height = 0,
                .make = try allocator.dupe(u8, "Unknown Make"),
                .model = try allocator.dupe(u8, "Stub Model"),
                .iso = 0,
                .shutter_speed = 0.0,
                .aperture = 0.0,
                .focal_length = 0.0,
                .color_matrix = [_]f32{0.0} ** 9,
                .white_balance = [_]f32{ 1.0, 1.0, 1.0 },
                .black_level = [_]f32{0.0} ** 4,
                .white_level = [_]u32{65535} ** 4,
                .raw_data_offset = 0,
                .raw_data_size = 0,
                .allocator = allocator,
            };
        },
        else => {
            // TODO: Add other format parsers
            return FormatError.UnsupportedFormat;
        },
    }
}

pub fn extract_raw_data(data: []const u8, metadata: RawMetadata, allocator: std.mem.Allocator) ![]u16 {
    // Extract raw data based on format
    switch (metadata.format) {
        .RW2 => return rw2.extract_raw_data(data, metadata, allocator),
        .Unknown => {
            // Return minimal stub data
            return try allocator.alloc(u16, 1);
        },
        else => {
            // TODO: Add other format extractors
            return FormatError.UnsupportedFormat;
        },
    }
}
