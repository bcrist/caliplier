pub fn main() !void {
    // debug_uart = @TypeOf(debug_uart).init();
    // debug_uart.start();

    usb.init();
    display.init();
    caliper.init();
    button.init();

    var inches = false;

    while (true) {
        switch (button.update()) {
            .none => {},
            .press => {
                const hid = microbe.usb.hid;
                const disp = if (inches) caliper.parse_inches() else caliper.parse_mm();
                for (&disp) |c| {
                    var report: hid.boot_keyboard.Input_Report = .{};
                    report.keys[0] = switch (c) {
                        '0' => .kb_0_cparen,
                        '1'...'9' => @enumFromInt(@intFromEnum(hid.page.Keyboard.kb_1_exclaim) + (c - '1')),
                        '.' => .period_greaterthan,
                        '-' => .kp_minus,
                        else => continue,
                    };
                    usb.keyboard_report.push(report);
                    usb.keyboard_report.push(.{});
                }
                var report: hid.boot_keyboard.Input_Report = .{};
                report.keys[0] = .kp_enter;
                usb.keyboard_report.push(report);
                usb.keyboard_report.push(.{});
            },
            .long_press => {
                inches = !inches;
            },
        }
        
        usb.update();

        const disp = if (inches) caliper.parse_inches() else caliper.parse_mm();
        display.update(&disp);
    }
}

pub const clocks: chip.clocks.Config = .{
    .xosc = .{},
    .sys_pll = .{ .frequency_hz = 100_000_000 },
    .usb_pll = .{ .frequency_hz = 48_000_000 },
    .usb = .{ .frequency_hz = 48_000_000 },
    .uart_spi = .{},
};

pub const handlers = struct {
    pub const SysTick = chip.timing.handle_tick_interrupt;
    pub const PWM_IRQ_WRAP = display.handle_interrupt;
    pub const IO_IRQ_BANK0 = caliper.handle_interrupt;
    // pub fn UART0_IRQ() void {
    //     debug_uart.handle_interrupt();
    // }
};

pub const panic = microbe.default_panic;
pub const std_options: std.Options = .{
    .logFn = microbe.default_nonblocking_log,
    .log_level = std.log.Level.warn,
    // .log_scope_levels = &.{
    //     .{ .scope = .main, .level = .info },
    // },
};

pub const debug_uart = &usb.uart;

// pub var debug_uart: chip.UART(.{
//     .baud_rate = 115207,
//     .tx = .GPIO0,
//     //.cts = .GPIO2,
//     .rx = null,
//     .tx_buffer_size = 4096,
// }) = undefined;

comptime {
    chip.init_exports();
}

const log = std.log.scoped(.main);

export const _boot2_checksum: u32 linksection(".boot2_checksum") = 0x25CF69B1;

const button = @import("button.zig");
const caliper = @import("caliper.zig");
const usb = @import("usb.zig");
const display = @import("display.zig");
const chip = @import("chip");
const microbe = @import("microbe");
const std = @import("std");
