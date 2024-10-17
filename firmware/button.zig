const debounce_time_us = 5000;
const long_press_min_duration_ms = 400;

const Button = microbe.bus.Bus(&.{ .GPIO22 }, .{
    .name = "Button",
    .State = State,
    .gpio_config = .{
        .hysteresis = true,
        .input_enabled = true,
        .maintenance = .pull_down,
    },
});

const State = enum (u1) {
    released = 0,
    pressed = 1,
};

pub const Action = enum {
    none,
    press,
    long_press,
};

var state: State = .released;
var state_changed: microbe.Microtick = @enumFromInt(0);
var last_bounce: microbe.Microtick = @enumFromInt(0);
var long_pressed: bool = false;

pub fn init() void {
    Button.init();
    Button.set_output_enable(false);
}

pub fn update() Action {
    const now = microbe.Microtick.now();
    const new_state = Button.read_inline();

    if (new_state == state) {
        last_bounce = now;
        if (!long_pressed and new_state == .pressed and state_changed.plus(.{ .ms = long_press_min_duration_ms }).is_before(now)) {
            long_pressed = true;
            return .long_press;
        }
        return .none;
    }

    if (now.is_before(last_bounce.plus(.{ .us = debounce_time_us }))) {
        return .none;
    }

    defer state = new_state;
    defer state_changed = now;

    if (new_state == .released) {
        if (long_pressed) {
            long_pressed = false;
        } else {
            return .press;
        }
    }
    return .none;
}

const log = std.log.scoped(.button);

const chip = @import("chip");
const microbe = @import("microbe");
const std = @import("std");
