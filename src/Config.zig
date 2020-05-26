// This file is part of river, a dynamic tiling wayland compositor.
//
// Copyright 2020 Isaac Freund
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const Self = @This();

const std = @import("std");

const c = @import("c.zig");

const Log = @import("log.zig").Log;
const Mode = @import("Mode.zig");
const Server = @import("Server.zig");
const Keybind = @import("Keybind.zig");

/// Width of borders in pixels
border_width: u32,

/// Amount of view padding in pixels
view_padding: u32,

/// Amount of padding arount the outer edge of the layout in pixels
outer_padding: u32,

/// All user-defined keybinding modes
modes: std.ArrayList(Mode),

/// List of app_ids which will be started floating
float_filter: std.ArrayList([*:0]const u8),

pub fn init(self: *Self, allocator: *std.mem.Allocator) !void {
    self.border_width = 2;
    self.view_padding = 8;
    self.outer_padding = 8;

    self.modes = std.ArrayList(Mode).init(allocator);
    try self.modes.append(try Mode.init("normal", allocator));

    self.float_filter = std.ArrayList([*:0]const u8).init(allocator);

    const normal = &self.modes.items[0];
    const mod = c.WLR_MODIFIER_LOGO;

    // Mod+Shift+Return to start an instance of alacritty
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_Return,
        mod | c.WLR_MODIFIER_SHIFT,
        &[_][]const u8{ "spawn", "alacritty" },
    ));

    // Mod+Q to close the focused view
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_q,
        mod,
        &[_][]const u8{"close"},
    ));

    // Mod+E to exit river
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_e,
        mod,
        &[_][]const u8{"exit"},
    ));

    // Mod+J and Mod+K to focus the next/previous view in the layout stack
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_j,
        mod,
        &[_][]const u8{ "focus", "next" },
    ));
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_k,
        mod,
        &[_][]const u8{ "focus", "previous" },
    ));

    // Mod+Return to bump the focused view to the top of the layout stack,
    // making it the new master
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_Return,
        mod,
        &[_][]const u8{"zoom"},
    ));

    // Mod+H and Mod+L to increase/decrease the width of the master column
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_h,
        mod,
        &[_][]const u8{ "mod_master_factor", "+0.05" },
    ));
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_l,
        mod,
        &[_][]const u8{ "mod_master_factor", "-0.05" },
    ));

    // Mod+Shift+H and Mod+Shift+L to increment/decrement the number of
    // master views in the layout
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_h,
        mod | c.WLR_MODIFIER_SHIFT,
        &[_][]const u8{ "mod_master_count", "+1" },
    ));
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_l,
        mod | c.WLR_MODIFIER_SHIFT,
        &[_][]const u8{ "mod_master_count", "+1" },
    ));

    comptime var i = 0;
    inline while (i < 9) : (i += 1) {
        const str = &[_]u8{i + '0' + 1};
        // Mod+[1-9] to focus tag [1-9]
        try normal.keybinds.append(try Keybind.init(
            allocator,
            c.XKB_KEY_1 + i,
            mod,
            &[_][]const u8{ "focus_tag", str },
        ));
        // Mod+Shift+[1-9] to tag focused view with tag [1-9]
        try normal.keybinds.append(try Keybind.init(
            allocator,
            c.XKB_KEY_1 + i,
            mod | c.WLR_MODIFIER_SHIFT,
            &[_][]const u8{ "tag_view", str },
        ));
        // Mod+Ctrl+[1-9] to toggle focus of tag [1-9]
        try normal.keybinds.append(try Keybind.init(
            allocator,
            c.XKB_KEY_1 + i,
            mod | c.WLR_MODIFIER_CTRL,
            &[_][]const u8{ "toggle_tag_focus", str },
        ));
        // Mod+Shift+Ctrl+[1-9] to toggle tag [1-9] of focused view
        try normal.keybinds.append(try Keybind.init(
            allocator,
            c.XKB_KEY_1 + i,
            mod | c.WLR_MODIFIER_CTRL | c.WLR_MODIFIER_SHIFT,
            &[_][]const u8{ "toggle_view_tag", str },
        ));
    }

    // Mod+0 to focus all tags
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_0,
        mod,
        &[_][]const u8{"focus_all_tags"},
    ));

    // Mod+Shift+0 to tag focused view with all tags
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_0,
        mod | c.WLR_MODIFIER_SHIFT,
        &[_][]const u8{"tag_view_all_tags"},
    ));

    // Mod+Period and Mod+Comma to focus the next/previous output
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_period,
        mod,
        &[_][]const u8{ "focus_output", "next" },
    ));
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_comma,
        mod,
        &[_][]const u8{ "focus_output", "previous" },
    ));

    // Mod+Shift+Period/Comma to send the focused view to the the
    // next/previous output
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_period,
        mod | c.WLR_MODIFIER_SHIFT,
        &[_][]const u8{ "send_to_output", "next" },
    ));
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_comma,
        mod | c.WLR_MODIFIER_SHIFT,
        &[_][]const u8{ "send_to_output", "previous" },
    ));

    // Mod+Space to toggle float
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_space,
        mod,
        &[_][]const u8{"toggle_float"},
    ));

    // Mod+F11 to enter passthrough mode
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_F11,
        mod,
        &[_][]const u8{ "mode", "passthrough" },
    ));

    try self.modes.append(try Mode.init("passthrough", allocator));

    // Mod+F11 to return to normal mode
    try self.modes.items[1].keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_F11,
        mod,
        &[_][]const u8{ "mode", "normal" },
    ));

    // Change master orientation with Mod+{Up,Right,Down,Left}
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_Up,
        mod,
        &[_][]const u8{ "layout", "TopMaster" },
    ));
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_Right,
        mod,
        &[_][]const u8{ "layout", "RightMaster" },
    ));
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_Down,
        mod,
        &[_][]const u8{ "layout", "BottomMaster" },
    ));
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_Left,
        mod,
        &[_][]const u8{ "layout", "LeftMaster" },
    ));

    // Mod+f to change to Full layout
    try normal.keybinds.append(try Keybind.init(
        allocator,
        c.XKB_KEY_f,
        mod,
        &[_][]const u8{ "layout", "Full" },
    ));

    // Float views with app_id "float"
    try self.float_filter.append("float");
}

pub fn deinit(self: Self, allocator: *std.mem.Allocator) void {
    for (self.modes.items) |*mode| mode.deinit();
    self.modes.deinit();
}

pub fn getMode(self: Self, name: []const u8) *Mode {
    for (self.modes.items) |*mode|
        if (std.mem.eql(u8, mode.name, name)) return mode;
    Log.Error.log("Mode '{}' does not exist, entering normal mode", .{name});
    for (self.modes.items) |*mode|
        if (std.mem.eql(u8, mode.name, "normal")) return mode;
    unreachable;
}
