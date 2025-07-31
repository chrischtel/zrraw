// src/formats/tiff/mod.zig - Common TIFF functionality
const std = @import("std");

pub const ByteOrder = enum { little, big };

// Common EXIF tags
pub const EXIF_MAKE = 0x010F;
pub const EXIF_MODEL = 0x0110;
pub const EXIF_ORIENTATION = 0x0112;
pub const EXIF_ISO = 0x8827;
pub const EXIF_SHUTTER_SPEED = 0x829A;
pub const EXIF_APERTURE = 0x829D;
pub const EXIF_FOCAL_LENGTH = 0x920A;

pub const IfdEntry = struct {
    tag: u16,
    data_type: u16,
    count: u32,
    value_offset: u32,
};

pub const IfdParser = struct {
    data: []const u8,
    byte_order: ByteOrder,

    pub fn init(data: []const u8, byte_order: ByteOrder) IfdParser {
        return IfdParser{ .data = data, .byte_order = byte_order };
    }

    pub fn read_u16(self: IfdParser, offset: usize) u16 {
        const bytes = self.data[offset .. offset + 2];
        return switch (self.byte_order) {
            .little => std.mem.readIntLittle(u16, bytes[0..2]),
            .big => std.mem.readIntBig(u16, bytes[0..2]),
        };
    }

    pub fn read_u32(self: IfdParser, offset: usize) u32 {
        const bytes = self.data[offset .. offset + 4];
        return switch (self.byte_order) {
            .little => std.mem.readIntLittle(u32, bytes[0..4]),
            .big => std.mem.readIntBig(u32, bytes[0..4]),
        };
    }

    pub fn parse_ifd(self: IfdParser, offset: u32) !Ifd {
        // Implementation for parsing IFD entries...
        // This would be a complete TIFF IFD parser
        _ = self;
        _ = offset;
        return Ifd.init();
    }
};

pub const Ifd = struct {
    entries: std.ArrayList(IfdEntry),

    pub fn init() Ifd {
        return Ifd{ .entries = std.ArrayList(IfdEntry).init(std.heap.page_allocator) };
    }

    pub fn get_string(self: Ifd, tag: u16) ?[]const u8 {
        // Find and return string value for tag
        _ = self;
        _ = tag;
        return null; // Placeholder
    }

    pub fn get_u32(self: Ifd, tag: u16) ?u32 {
        // Find and return u32 value for tag
        _ = self;
        _ = tag;
        return null; // Placeholder
    }
};
