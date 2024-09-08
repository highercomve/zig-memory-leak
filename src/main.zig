const std = @import("std");
const builtin = @import("builtin");

const Data = std.StringHashMap([]const u8);

pub fn getGpaConfig() std.heap.GeneralPurposeAllocatorConfig {
    if (builtin.mode == .Debug) {
        return std.heap.GeneralPurposeAllocatorConfig{
            .safety = true,
            .never_unmap = true,
            .retain_metadata = true,
            .verbose_log = false,
        };
    } else {
        return std.heap.GeneralPurposeAllocatorConfig{
            .safety = false,
            .never_unmap = false,
            .retain_metadata = false,
            .verbose_log = false,
        };
    }
}

pub fn main() !void {
    _ = try process_data();
}

fn process_data() ![]const u8 {
    const config = getGpaConfig();
    var gpa = std.heap.GeneralPurposeAllocator(config){};
    defer {
        const check = gpa.deinit();
        std.debug.print("Gpa check = {any}\n", .{check});
    }
    const allocator = gpa.allocator();

    var map = Data.init(allocator);
    try map.put("state", "one");
    try map.put("folder", "/this/is/a/test");

    return try convert_to_json(allocator, &map);
}

fn convert_to_json(allocator: std.mem.Allocator, data: *Data) ![]const u8 {
    var json_object = std.json.ObjectMap.init(allocator);
    defer json_object.deinit();

    var it = data.iterator();
    while (it.next()) |entry| {
        try json_object.put(entry.key_ptr.*, std.json.Value{ .string = entry.value_ptr.* });
    }

    const json_value = std.json.Value{ .object = json_object };
    const json_string = try std.json.stringifyAlloc(allocator, json_value, .{});

    return json_string;
}

test "simple test" {
    const string = try process_data();

    try std.testing.expect(std.mem.eql(u8, string, "{\"folder\":\"/this/is/a/test\",\"state\":\"one\"}"));
}
