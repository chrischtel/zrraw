const std = @import("std");
const mod = @import("mod.zig");

pub fn parse_metadata(data: []const u8, allocator: std.mem.Allocator) !mod.RawMetadata {
    return mod.parse_metadata(data, allocator);
}

pub fn extract_raw_data(data: []const u8, metadata: mod.RawMetadata, allocator: std.mem.Allocator) ![]u16 {
    return mod.extract_raw_data(data, metadata, allocator);
}
