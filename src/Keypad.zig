const Self = @This();
const std = @import("std");

const key_count = 16;

pub const KeyState = enum {
    up,
    down,
};

/// 1, 2, 3, c,
/// 4, 5, 6, d,
/// 7, 8, 9, e,
/// a, 0, b, f,
pub const Key = enum(u8) {
    key_0,
    key_1,
    key_2,
    key_3,
    key_4,
    key_5,
    key_6,
    key_7,
    key_8,
    key_9,
    key_a,
    key_b,
    key_c,
    key_d,
    key_e,
    key_f,

    pub fn toUInt(key: Key) u8 {
        return @intFromEnum(key);
    }

    pub fn fromUInt(val: u8) Key {
        return @enumFromInt(val);
    }
};

keys: [key_count]KeyState = [_]KeyState{.up} ** key_count,

pub fn init() Self {
    return .{};
}

pub fn getState(self: *Self, key: Key) KeyState {
    return self.keys[@intFromEnum(key)];
}

pub fn putState(self: *Self, key: Key, state: KeyState) void {
    self.keys[@intFromEnum(key)] = state;
}
