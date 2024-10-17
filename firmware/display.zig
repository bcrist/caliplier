// pwm clock = 1.5151 MHz
// interrupt frequency = 3.03 kHz
// full refresh frequency = 505 Hz
const clock_divisor = 66;
const max_count = 500;

pub const digit_count = 6;

const Digit = packed struct (u8) {
    a: bool = true,
    b: bool = true,
    c: bool = true,
    d: bool = true,
    e: bool = true,
    f: bool = true,
    g: bool = true,
    dp: bool = false,

    pub const blank: Digit = @bitCast(@as(u8, 0));
    pub const dash: Digit = .{ .a = false, .b = false, .c = false, .d = false, .e = false, .f = false };
    pub const err: Digit = .{ .b = false, .c = false };
    pub const decimal: [10]Digit = .{
        .{ .g = false }, // 0
        .{ .a = false, .d = false, .e = false, .f = false, .g = false }, // 1
        .{ .f = false, .c = false }, // 2
        .{ .f = false, .e = false }, // 3
        .{ .a = false, .d = false, .e = false }, // 4
        .{ .b = false, .e = false }, // 5
        .{ .b = false }, // 6
        .{ .d = false, .e = false, .f = false, .g = false }, // 7
        .{}, // 8
        .{ .e = false }, // 9
    };

    pub fn with_dp(self: Digit) Digit {
        var result = self;
        result.dp = true;
        return result;
    }

    pub fn from_ascii(c: u8) Digit {
        return switch (c) {
            '0'...'9' => Digit.decimal[c - '0'],
            '-' => Digit.dash,
            ' ' => Digit.blank,
            else => Digit.err,
        };
    }
};

const Segments = microbe.bus.Bus(&.{ .GPIO8, .GPIO9, .GPIO10, .GPIO11, .GPIO12, .GPIO13, .GPIO14, .GPIO15 }, .{
    .name = "Segments",
    .State = Digit,
    .gpio_config = .{
        .speed = .slow,
        .strength = .@"2mA",
    },
});

const Digit_Select = microbe.bus.Bus(&.{ .GPIO16, .GPIO17, .GPIO18, .GPIO19, .GPIO20, .GPIO21 }, .{
    .name = "Digit_Select",
    .gpio_config = .{
        .speed = .slow,
        .strength = .@"2mA",
    },
});

const Disable_Interrupt = chip.PWM(.{
    .name = "Digit Disable Interrupt",
    .channel = .ch0,
    .output = null,
    .clock = .{ .divisor_16ths = clock_divisor * 16 },
    .max_count = max_count,
});
const Enable_Interrupt = chip.PWM(.{
    .name = "Digit Enable Interrupt",
    .channel = .ch1,
    .output = null,
    .clock = .{ .divisor_16ths = clock_divisor * 16 },
    .max_count = max_count,
});

var state: [digit_count]Digit = .{ Digit.dash } ** digit_count;
var current_digit: u8 = 0;
var current_digit_mask: u6 = 0;

pub fn init() void {
    Segments.init();
    Segments.set_output_enable(true);
    Segments.modify(.blank);

    Digit_Select.init();
    Digit_Select.set_output_enable(true);
    Digit_Select.modify(0);

    Enable_Interrupt.init();
    Disable_Interrupt.init();

    Disable_Interrupt.start();
    while (Disable_Interrupt.read() != 1) {}
    Enable_Interrupt.start();

    chip.peripherals.PWM.irq.raw.clear_bits(.{ .ch0 = true, .ch1 = true });
    chip.peripherals.PWM.irq.enable.modify(.{ .ch0 = true, .ch1 = true });

    chip.peripherals.NVIC.interrupt_clear_pending.write(.{ .PWM_IRQ_WRAP = true });
    chip.peripherals.NVIC.interrupt_set_enable.write(.{ .PWM_IRQ_WRAP = true });

    log.info("initialized", .{});
}

pub fn update(ascii: []const u8) void {
    var next_digit: u8 = 0;
    for (ascii) |d| {
        if (d == '.') {
            if (next_digit == 0) {
                state[0] = Digit.blank.with_dp();
                next_digit += 1;
            } else {
                state[next_digit - 1].dp = true;
            }
        } else {
            if (next_digit == digit_count) break;
            state[next_digit] = .from_ascii(d);
            next_digit += 1;
        }
    }
}

pub fn handle_interrupt() void {
    const which = chip.peripherals.PWM.irq.status.read();
    chip.peripherals.PWM.irq.raw.clear_bits(.{ .ch0 = true, .ch1 = true });

    if (which.ch0) {
        // disable all outputs
        Segments.modify(.blank);
        Digit_Select.modify(0);
    } else if (which.ch1) {
        // enable the next digit
        var next_digit = current_digit -% 1;
        var next_mask = current_digit_mask >> 1;
        if (next_mask == 0) {
            next_digit = digit_count - 1;
            next_mask = 1 << (digit_count - 1);
        }

        Segments.modify(state[next_digit]);
        Digit_Select.modify(next_mask);

        current_digit = next_digit;
        current_digit_mask = next_mask;
    }
}

const log = std.log.scoped(.matrix);

const chip = @import("chip");
const microbe = @import("microbe");
const std = @import("std");
