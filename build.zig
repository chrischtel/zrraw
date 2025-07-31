const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Static library for FFI
    const lib = b.addSharedLibrary(.{
        .name = "zrraw",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
    });

    // Export symbols for C/FFI
    lib.bundle_compiler_rt = true;

    // Install the library
    b.installArtifact(lib);

    // Generate header
    generateHeader(b);

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn generateHeader(b: *std.Build) void {
    const header_step = b.addWriteFiles();
    const header_content =
        \\#ifndef ZRRAW_H
        \\#define ZRRAW_H
        \\
        \\#include <stdint.h>
        \\#include <stdbool.h>
        \\#include <stddef.h>
        \\
        \\#ifdef __cplusplus
        \\extern "C" {
        \\#endif
        \\
        \\// Error codes
        \\typedef enum {
        \\    ZRRAW_SUCCESS = 0,
        \\    ZRRAW_INVALID_INPUT = -1,
        \\    ZRRAW_UNSUPPORTED_FORMAT = -2,
        \\    ZRRAW_PARSE_ERROR = -3,
        \\    ZRRAW_OUT_OF_MEMORY = -4,
        \\    ZRRAW_IO_ERROR = -5,
        \\    ZRRAW_CORRUPTED_DATA = -6,
        \\} ZrRawError;
        \\
        \\// Raw formats
        \\typedef enum {
        \\    ZRRAW_FORMAT_UNKNOWN = 0,
        \\    ZRRAW_FORMAT_CR2 = 1,
        \\    ZRRAW_FORMAT_NEF = 2,
        \\    ZRRAW_FORMAT_ARW = 3,
        \\    ZRRAW_FORMAT_DNG = 4,
        \\    ZRRAW_FORMAT_RAF = 5,
        \\    ZRRAW_FORMAT_ORF = 6,
        \\    ZRRAW_FORMAT_RW2 = 7,
        \\    ZRRAW_FORMAT_PEF = 8,
        \\    ZRRAW_FORMAT_X3F = 9,
        \\} ZrRawFormat;
        \\
        \\// Orientation values
        \\typedef enum {
        \\    ZRRAW_ORIENTATION_NORMAL = 1,
        \\    ZRRAW_ORIENTATION_FLIP_H = 2,
        \\    ZRRAW_ORIENTATION_ROTATE_180 = 3,
        \\    ZRRAW_ORIENTATION_FLIP_V = 4,
        \\    ZRRAW_ORIENTATION_TRANSPOSE = 5,
        \\    ZRRAW_ORIENTATION_ROTATE_90 = 6,
        \\    ZRRAW_ORIENTATION_TRANSVERSE = 7,
        \\    ZRRAW_ORIENTATION_ROTATE_270 = 8,
        \\} ZrRawOrientation;
        \\
        \\// Demosaic algorithms
        \\typedef enum {
        \\    ZRRAW_DEMOSAIC_FAST = 0,
        \\    ZRRAW_DEMOSAIC_QUALITY = 1,
        \\    ZRRAW_DEMOSAIC_BEST = 2,
        \\} ZrRawDemosaic;
        \\
        \\// Processing parameters
        \\typedef struct {
        \\    ZrRawDemosaic demosaic_algorithm;
        \\    float wb_temperature;
        \\    float wb_tint;
        \\    float highlight_recovery;
        \\    float shadow_lift;
        \\    float exposure_compensation;
        \\    float output_gamma;
        \\    bool output_16bit;
        \\} ZrRawProcessParams;
        \\
        \\// Metadata structure
        \\typedef struct {
        \\    ZrRawFormat format;
        \\    uint32_t width;
        \\    uint32_t height;
        \\    ZrRawOrientation orientation;
        \\    char make[64];
        \\    char model[64];
        \\    uint32_t iso;
        \\    uint32_t shutter_speed_num;
        \\    uint32_t shutter_speed_den;
        \\    uint32_t aperture_num;
        \\    uint32_t aperture_den;
        \\    float focal_length;
        \\    float color_matrix[9];
        \\    float white_balance[3];
        \\    float black_level[4];
        \\    uint32_t white_level[4];
        \\    uint8_t _reserved[32];
        \\} ZrRawMetadata;
        \\
        \\// Image data structure
        \\typedef struct {
        \\    uint32_t width;
        \\    uint32_t height;
        \\    uint32_t channels;
        \\    uint32_t bits_per_channel;
        \\    uint8_t* data;
        \\    size_t data_size;
        \\    void* _allocator;
        \\    uint8_t _reserved[16];
        \\} ZrRawImage;
        \\
        \\// Function declarations
        \\ZrRawError zrraw_detect_format(const uint8_t* data, size_t data_len, ZrRawFormat* format);
        \\ZrRawError zrraw_extract_metadata(const uint8_t* data, size_t data_len, ZrRawMetadata* metadata);
        \\ZrRawError zrraw_process_image(const uint8_t* data, size_t data_len, const ZrRawProcessParams* params, ZrRawImage* result_image, ZrRawMetadata* result_metadata);        
        \\void zrraw_free_image(ZrRawImage* image);
        \\const char* zrraw_version(void);
        \\uint32_t zrraw_supported_formats(void);
        \\
        \\#ifdef __cplusplus
        \\}
        \\#endif
        \\
        \\#endif // ZRRAW_H
    ;

    const header_file = header_step.add("zrraw.h", header_content);
    const install_header = b.addInstallFile(header_file, "include/zrraw.h");
    b.getInstallStep().dependOn(&install_header.step);
}
