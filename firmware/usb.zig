pub fn get_device_descriptor() descriptor.Device {
    return .{
        .usb_version = .usb_1_1,
        .class = classes.composite_device,
        .vendor_id = 0x1209,
        .product_id = 0x057D,
        .version = .{
            .major = 1,
            .minor = 0,
        },
        .configuration_count = @intCast(configurations.len),
    };
}

const languages: descriptor.Supported_Languages(&.{
    .english_us,
}) = .{};
const strings = struct {
    const mfr_name: descriptor.String("Magic / More Magic") = .{};
    const product_name: descriptor.String("Caliplier") = .{};
    const serial_number: descriptor.String("1") = .{};
};

pub fn get_string_descriptor(id: descriptor.String_ID, language: descriptor.Language) ?[]const u8 {
    if (id == .languages) return std.mem.asBytes(&languages);
    return switch (language) {
        .english_us => switch (id) {
            .manufacturer_name => std.mem.asBytes(&strings.mfr_name),
            .product_name => std.mem.asBytes(&strings.product_name),
            .serial_number => std.mem.asBytes(&strings.serial_number),
            else => null,
        },
        else => null,
    };
}

pub const default_configuration = struct {
    pub const keyboard_interface = struct {
        pub const index = 0;
        pub const class = usb.hid.class.boot_keyboard;

        pub const in_endpoint = struct {
            pub const address: endpoint.Address = .{ .ep = 1, .dir = .in };
            pub const kind: endpoint.Transfer_Kind = .interrupt;
            pub const poll_interval_ms: u8 = 4;
        };

        pub const endpoints = .{ in_endpoint };

        pub const hid_descriptor: usb.hid.boot_keyboard.HID_Descriptor = .{};
        pub const report_descriptor: usb.hid.boot_keyboard.Report_Descriptor = .{};

        pub const Report = usb.hid.boot_keyboard.Input_Report;
        pub const Status = usb.hid.boot_keyboard.Output_Report;
    };

    pub const comm_interface = struct {
        pub const index = 1;
        pub const class = usb.cdc_acm.class.control_interface;

        pub const notification_endpoint = struct {
            pub const address: endpoint.Address = .{ .ep = 2, .dir = .in };
            pub const kind: endpoint.Transfer_Kind = .interrupt;
            pub const poll_interval_ms: u8 = 100;
        };

        pub const endpoints = .{ notification_endpoint };
    };

    pub const data_interface = struct {
        pub const index = 2;
        pub const class = usb.cdc_acm.class.data_interface;

        pub const in_endpoint = struct {
            pub const address: endpoint.Address = .{ .ep = 3, .dir = .in };
            pub const kind: endpoint.Transfer_Kind = .bulk;
        };
        pub const out_endpoint = struct {
            pub const address: endpoint.Address = .{ .ep = 3, .dir = .out };
            pub const kind: endpoint.Transfer_Kind = .bulk;
        };

        pub const endpoints = .{ in_endpoint, out_endpoint };
    };

    pub const interfaces = .{
        keyboard_interface,
        comm_interface,
        data_interface,
    };

    pub const descriptors: Descriptor_Set = .{};
    pub const Descriptor_Set = packed struct {
        config: descriptor.Configuration = .{
            .number = 1,
            .name = @enumFromInt(0),
            .self_powered = false,
            .remote_wakeup = false,
            .max_current_ma_div2 = 50,
            .length_bytes = @bitSizeOf(Descriptor_Set) / 8,
            .interface_count = @intCast(interfaces.len),
        },
        keyboard_interface: descriptor.Interface = descriptor.Interface.parse(keyboard_interface),
        keyboard_hid: usb.hid.boot_keyboard.HID_Descriptor = keyboard_interface.hid_descriptor,
        keyboard_hid_in_ep: descriptor.Endpoint = descriptor.Endpoint.parse(keyboard_interface.in_endpoint),
        
        iad: descriptor.Interface_Association = .{
            .first_interface = comm_interface.index,
            .interface_count = 2,
            .function_class = comm_interface.class,
            .name = @enumFromInt(0),
        },
        comm_interface: descriptor.Interface = descriptor.Interface.parse(comm_interface),
        cdc_header: usb.cdc_acm.Header_Descriptor = .{},
        call_mgmt: usb.cdc_acm.Call_Management_Descriptor = .{
            .data_interface_index = data_interface.index,
        },
        acm: usb.cdc_acm.Abstract_Control_Management_Descriptor = .{},
        @"union": usb.cdc_acm.Union_Descriptor = .{
            .control_interface_index = comm_interface.index,
            .data_interface_index = data_interface.index,
        },
        notification_endpoint: descriptor.Endpoint = descriptor.Endpoint.parse(comm_interface.notification_endpoint),
        data_interface: descriptor.Interface = descriptor.Interface.parse(data_interface),
        in_endpoint: descriptor.Endpoint = descriptor.Endpoint.parse(data_interface.in_endpoint),
        out_endpoint: descriptor.Endpoint = descriptor.Endpoint.parse(data_interface.out_endpoint),
    };
};

const configurations = .{ default_configuration };

pub fn get_configuration_descriptor_set(configuration_index: u8) ?[]const u8 {
    inline for (0.., configurations) |i, configuration| {
        if (i == configuration_index) {
            const bytes = @bitSizeOf(configuration.Descriptor_Set) / 8;
            return std.mem.asBytes(&configuration.descriptors)[0..bytes];
        }
    }
    return null;
}

pub fn get_interface_count(configuration: u8) u8 {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            return @intCast(cfg.interfaces.len);
        }
    }
    return 0;
}

pub fn get_endpoint_count(configuration: u8, interface_index: u8) u8 {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            inline for (0.., cfg.interfaces) |j, interface| {
                if (j == interface_index) {
                    return @intCast(interface.endpoints.len);
                }
            }
        }
    }
    return 0;
}

// Endpoint descriptors are not queried directly by hosts, but these are used to set up
// the hardware configuration for each endpoint.
pub fn get_endpoint_descriptor(configuration: u8, interface_index: u8, endpoint_index: u8) descriptor.Endpoint {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            inline for (0.., cfg.interfaces) |j, iface| {
                if (j == interface_index) {
                    inline for (0.., iface.endpoints) |k, ep| {
                        if (k == endpoint_index) {
                            return descriptor.Endpoint.parse(ep);
                        }
                    }
                }
            }
        }
    }
    unreachable;
}

/// This function can be used to provide class-specific descriptors associated with the device
pub fn get_descriptor(kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    _ = kind;
    return null;
}

/// This function can be used to provide class-specific descriptors associated with a particular interface, e.g. HID report descriptors
pub fn get_interface_specific_descriptor(interface: u8, kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    switch (interface) {
        default_configuration.keyboard_interface.index => {
            const ki = default_configuration.keyboard_interface;
            switch (kind) {
                usb.hid.hid_descriptor => {
                    return ki.hid_descriptor.as_bytes();
                },
                usb.hid.report_descriptor => {
                    return ki.report_descriptor.as_bytes();
                },
                else => {},
            }
        },
        else => {},
    }
    return null;
}

/// This function can be used to provide class-specific descriptors associated with a particular endpoint
pub fn get_endpoint_specific_descriptor(ep: endpoint.Index, kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    _ = kind;
    _ = ep;
    return null;
}

/// This function determines whether the USB engine should reply to non-control transactions with ACK or NAK
/// For .in endpoints, this should return true when we have some data to send.
/// For .out endpoints, this should return true when we can handle at least the max packet size of data for this endpoint.
pub fn is_endpoint_ready(address: endpoint.Address) bool {
    switch (address.dir) {
        .in => switch (address.ep) {
            default_configuration.keyboard_interface.in_endpoint.address.ep => {
                return keyboard_report.is_endpoint_ready();
            },
            default_configuration.comm_interface.notification_endpoint.address.ep => {
                return uart.received_encapsulated_command;
            },
            default_configuration.data_interface.in_endpoint.address.ep => {
                return !uart.is_tx_idle();
            },
            else => {},
        },
        .out => switch (address.ep) {
            default_configuration.data_interface.out_endpoint.address.ep => {
                return !uart.is_rx_full();
            },
            else => {},
        },
    }
    return false;
}

/// The buffer returned from this function only needs to remain valid briefly; it will be copied to an internal buffer.
/// If you don't have a buffer available, you can instead define:
pub fn fill_in_buffer(ep: endpoint.Index, data: []u8) u16 {
    switch (ep) {
        default_configuration.keyboard_interface.in_endpoint.address.ep => {
            const b = keyboard_report.get_in_buffer();
            @memcpy(data.ptr, b);
            return @intCast(b.len);
        },
        default_configuration.comm_interface.notification_endpoint.address.ep => {
            uart.received_encapsulated_command = false;
            const result = usb.cdc_acm.notifications.responseAvailable(default_configuration.comm_interface.index);
            std.debug.assert(data.len >= @sizeOf(@TypeOf(result)));
            @memcpy(data.ptr, std.mem.asBytes(&result));
            return @bitSizeOf(@TypeOf(result)) / 8;
        },
        default_configuration.data_interface.in_endpoint.address.ep => {
            return uart.fill_in_buffer(data);
        },
        else => {},
    }
    return 0;
}

pub fn handle_out_buffer(ep: endpoint.Index, data: []volatile const u8) void {
    switch (ep) {
        default_configuration.data_interface.out_endpoint.address.ep => {
            uart.handle_out_buffer(data);
        },
        else => {},
    }
}

/// Called when a SOF packet is received
pub fn handle_start_of_frame() void {
    keyboard_report.handle_start_of_frame();
}

/// Called when the host resets the bus
pub fn handle_bus_reset() void {
    keyboard_report.reset();
}

/// Called when a set_configuration setup request is processed
pub fn handle_configuration_changed(configuration: u8) void {
    _ = configuration;
}

/// Called when the USB connection state changes
pub fn handle_state_changed(state: usb.State) void {
    log.info("{}", .{ state });
}

/// Used to respond to the get_status setup request
pub fn is_device_self_powered() bool {
    return false;
}

/// Handle any class/device-specific setup requests here.
/// Return true if the setup request is recognized and handled.
///
/// Requests where setup.data_len == 0 should call `device.setup_status_in()`.
/// Note this is regardless of whether setup.direction is .in or .out.
///
/// .in requests with a non-zero length should make one or more calls to `device.fill_setup_in(offset, data)`,
/// followed by a call to `device.setup_transfer_in(total_length)`, or just a single
/// call to `device.setup_transfer_in_data(data)`.  The data may be larger than the maximum EP0 transfer size.
/// In that case the data will need to be provided again using the `fill_setup_in` function below.
///
/// .out requests with a non-zero length should call `device.setup_transfer_out(setup.data_len)`.
/// The data will then be provided later via `handle_setup_out_buffer`
///
/// Note that this gets called even for standard requests that are normally handled internally.
/// You _must_ check that the packet matches what you're looking for specifically.
pub fn handle_setup(setup: Setup_Packet) bool {
    if (uart.handle_setup(setup)) return true;
    if (keyboard_report.handle_setup(setup)) return true;
    if (keyboard_status.handle_setup(setup)) return true;
    if (setup.kind == .class and setup.target == .interface) switch (setup.request) {
        usb.hid.requests.set_protocol => if (setup.direction == .out) {
            const payload: usb.hid.requests.Protocol_Payload = @bitCast(setup.payload);
            if (payload.interface == default_configuration.keyboard_interface.index) {
                log.info("set protocol: {}", .{ payload.protocol });
                device.setup_status_in();
                return true;
            }
        },
        usb.hid.requests.get_protocol => if (setup.direction == .in) {
            const payload: usb.hid.requests.Protocol_Payload = @bitCast(setup.payload);
            if (payload.interface == default_configuration.keyboard_interface.index) {
                log.info("get protocol", .{});
                const protocol: u8 = 0;
                device.setup_transfer_in_data(std.mem.asBytes(&protocol));
                return true;
            }
        },
        else => {},
    };
    return false;
}

/// If an .in setup request's data is too large for a single data packet,
/// this will be called after each buffer is transferred to fill in the next buffer.
/// If it returns false, endpoint 0 will be stalled.
/// Otherwise, it is assumed that the entire remaining data, or the entire buffer (whichever is smaller)
/// will be filled with data to send.
/// 
/// Normally this function should make one or more calls to `device.fill_setup_in(offset, data)`,
/// corresponding to the entire data payload, including parts that have already been sent.  The
/// parts outside the current buffer will automatically be ignored.
pub fn fill_setup_in(setup: Setup_Packet) bool {
    _ = setup;
    return false;
}

/// Return true if the setup request is recognized and the data buffer was processed.
pub fn handle_setup_out_buffer(setup: Setup_Packet, offset: u16, data: []volatile const u8, last_buffer: bool) bool {
    return keyboard_status.handle_setup_out_buffer(setup, offset, data)
        or uart.handle_setup_out_buffer(setup, offset, data, last_buffer)
        ;
}

pub fn init() void {
    device.init();
    uart = @TypeOf(uart).init(&device);
    keyboard_report = @TypeOf(keyboard_report).init(&device);
    keyboard_status = @TypeOf(keyboard_status).init(&device);
}

pub fn update() void {
    device.update();
    while (true) {
        var buf: [32]u8 = undefined;
        const bytes = uart.reader_nonblocking().read(&buf) catch break;
        log.info("received: {s}", .{ buf[0..bytes] });
    }
}

var device: usb.USB(@This()) = .{};

pub var uart: usb.cdc_acm.UART(@This(), .{
    .communications_interface_index = default_configuration.comm_interface.index,
    .rx_packet_size = 64,
    .tx_buffer_size = 8192,
}) = undefined;

pub var keyboard_report: usb.hid.Input_Reporter(@This(), default_configuration.keyboard_interface.Report, .{
    .max_buffer_size = 32,
    .interface_index = default_configuration.keyboard_interface.index,
    .report_id = 0,
    .default_idle_interval = .@"500ms",
}) = undefined;
pub var keyboard_status: usb.hid.Output_Reporter(@This(), default_configuration.keyboard_interface.Status, .{
    .interface_index = default_configuration.keyboard_interface.index,
    .report_id = 0,
}) = undefined;

const log = std.log.scoped(.hid);

const descriptor = usb.descriptor;
const endpoint = usb.endpoint;
const classes = usb.classes;
const Setup_Packet = usb.Setup_Packet;
const usb = @import("microbe").usb;
const std = @import("std");
