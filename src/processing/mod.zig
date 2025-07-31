const std = @import("std");
const root = @import("../root.zig");

pub const ProcessedImage = struct {
    width: u32,
    height: u32,
    channels: u32,
    bits_per_channel: u32,
    data: []u8,

    pub fn to_ffi(self: ProcessedImage) root.ZrRawImage {
        return root.ZrRawImage{
            .width = self.width,
            .height = self.height,
            .channels = self.channels,
            .bits_per_channel = self.bits_per_channel,
            .data = self.data.ptr,
            .data_size = self.data.len,
            ._allocator = @as(*anyopaque, @ptrCast(@constCast(&std.heap.c_allocator))),
            ._reserved = [_]u8{0} ** 16,
        };
    }
};

pub fn process_raw(data: []const u8, params: root.ZrRawProcessParams) !ProcessedImage {
    _ = data;
    _ = params;

    const allocator = std.heap.c_allocator;
    const dummy_data = try allocator.alloc(u8, 3);
    dummy_data[0] = 255;
    dummy_data[1] = 0;
    dummy_data[2] = 0;

    return ProcessedImage{
        .width = 1,
        .height = 1,
        .channels = 3,
        .bits_per_channel = 8,
        .data = dummy_data,
    };
}
