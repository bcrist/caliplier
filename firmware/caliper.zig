// Note there are several caliper data formats out there.
// If this doesn't work, your caliper may be using a different protocol.

const expected_packet_bits = 24;
const max_bit_delay_us = 5000;
const min_packet_ticks = 8000;
const max_packet_ticks = 8200;

const Caliper = microbe.bus.Bus(&.{ .GPIO23, .GPIO24 }, .{
    .name = "Caliper Interface",
    .gpio_config = .{
        .hysteresis = true,
        .input_enabled = true,
    },
});

var next_raw: u64 = 0;
var bits_received: u16 = 0;
var last_bit_received: microbe.Microtick = @enumFromInt(0);
var packet_begin: microbe.Microtick = @enumFromInt(0);

pub var last_value: u64 = 0;

pub fn init() void {
    Caliper.init();
    Caliper.set_output_enable(false);

    chip.peripherals.IO_INT.core0.enable.gpio_16_to_23.set_bits(.{
        .gpio23_rising = true,
    });

    chip.peripherals.NVIC.interrupt_clear_pending.write(.{ .IO_IRQ_BANK0 = true });
    chip.peripherals.NVIC.interrupt_set_enable.write(.{ .IO_IRQ_BANK0 = true });
}

pub fn handle_interrupt() void {
    const status23 = chip.peripherals.IO_INT.core0.status.gpio_16_to_23.read();
    if (!status23.gpio23_rising) return;

    chip.peripherals.IO_INT.interrupt_status.gpio_16_to_23.clear_bits(.{
        .gpio23_rising = true,
    });
    const state = Caliper.read_inline();
    const now = microbe.Microtick.now();

    if (last_bit_received.plus(.{ .us = max_bit_delay_us }).is_before(now)) {
        // it's been a long time since the previous bit, so we can assume this is the start of a new packet
        const delta_ticks = last_bit_received.ticks_since(packet_begin);
        log.debug("Received {} bits in {} microticks: {b}", .{ bits_received, delta_ticks, next_raw });
        if (bits_received == expected_packet_bits) {
            if (delta_ticks >= min_packet_ticks and delta_ticks <= max_packet_ticks) {
                if ((next_raw & 1) == 1) {
                    const old_value = last_value;
                    const new_value = next_raw >> 1;
                    last_value = new_value;
                    if (old_value != new_value) {
                        log.info("Packet changed: {X} ({s} mm / {s} in)", .{ new_value, &parse_mm(), &parse_inches() });
                    }
                } else {
                    log.warn("Expected packet start bit to be a 1", .{});
                }
            } else {
                log.warn("Packet reception took {} ticks; expected between {} and {}", .{ delta_ticks, min_packet_ticks, max_packet_ticks });
            }
        } else {
            log.warn("Expected {} bits per packet but found {}", .{ expected_packet_bits, bits_received });
        }
        bits_received = 0;
        next_raw = 0;
        packet_begin = now;
    }

    const bit: u64 = switch (state) {
        0, 2 => {
            log.warn("Found low clock during interrupt handler; possible noise?  Resetting state...", .{});
            bits_received = 0;
            return;
        },
        1 => 1,
        3 => 0,
    };

    if (bits_received < 64) {
        next_raw |= bit << @intCast(bits_received);
    }
    bits_received += 1;
    last_bit_received = now;
}

pub fn parse_mm() [7]u8 {
    const value = last_value;
    const ipart = (value & 0xFFFFF) / 100;
    const dpart = (value & 0xFFFFF) % 100;

    var buf: [7]u8 = .{ ' ' } ** 7;

    _ = std.fmt.bufPrint(&buf, "{d:>4}.{:0>2}", .{ ipart, dpart }) catch {};

    if ((value & 0x100000) != 0) {
        var i: usize = buf.len;
        while (i > 0) {
            i -= 1;
            if (buf[i] == ' ') {
                buf[i] = '-';
                break;
            }
        }
    }

    {
        var i: usize = buf.len;
        while (i > 0) {
            i -= 1;
            if (buf[i] == '0') {
                buf[i] = ' ';
            } else break;
        }
    }

    return buf;
}

pub fn parse_inches() [7]u8 {
    const value = last_value;
    const ipart = (value & 0xFFFFF) / 2000;
    const dpart = ((value & 0xFFFFF) % 2000) * 5;

    var buf: [7]u8 = .{ ' ' } ** 7;

    _ = std.fmt.bufPrint(&buf, "{d:>2}.{:0>4}", .{ ipart, dpart }) catch {};

    if ((value & 0x100000) != 0) {
        var i: usize = buf.len;
        while (i > 0) {
            i -= 1;
            if (buf[i] == ' ') {
                buf[i] = '-';
                break;
            }
        }
    }

    {
        var i: usize = buf.len;
        while (i > 0) {
            i -= 1;
            if (buf[i] == '0') {
                buf[i] = ' ';
            } else break;
        }
    }

    return buf;
}

const log = std.log.scoped(.caliper);

const chip = @import("chip");
const microbe = @import("microbe");
const std = @import("std");