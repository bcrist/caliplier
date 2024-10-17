pub fn build(b: *std.Build) void {
    const chip = rpi.rp2040(rpi.zd25q80c);

    const boot2_object = rpi.add_boot2_object(b, .{
        .source = .{ .module = b.dependency("microbe-rpi", .{}).module("boot2-default") },
        .chip = chip,
        .optimize = .ReleaseSmall,
    });

    const exe = microbe.add_executable(b, .{
        .name = "firmware.elf",
        .root_source_file = b.path("firmware/main.zig"),
        .chip = chip,
        .sections = rpi.default_rp2040_sections(),
        .optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall }),
        .breakpoint_on_panic = false,
    });
    exe.addObject(boot2_object);

    const install_elf = b.addInstallArtifact(exe, .{});
    const copy_elf = b.addInstallBinFile(exe.getEmittedBin(), "firmware.elf");

    const bin = exe.addObjCopy(.{ .format = .bin });
    const checksummed_bin = rpi.boot2_checksum(b, bin.getOutput());
    const install_bin = b.addInstallBinFile(checksummed_bin, "firmware.bin");

    const uf2 = microbe.add_bin_to_uf2(b, "firmware.uf2", &.{
        .{
            .path = checksummed_bin,
            .family = .rp2040,
            .base_address = 0x10000000
        },
    });
    const install_uf2 = b.addInstallBinFile(uf2, "firmware.uf2");

    b.getInstallStep().dependOn(&install_elf.step);
    b.getInstallStep().dependOn(&copy_elf.step);
    b.getInstallStep().dependOn(&install_bin.step);
    b.getInstallStep().dependOn(&install_uf2.step);
}

const microbe = @import("microbe");
const rpi = @import("microbe-rpi");
const std = @import("std");
