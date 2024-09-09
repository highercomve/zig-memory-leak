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
    const config = getGpaConfig();
    var gpa = std.heap.GeneralPurposeAllocator(config){};
    defer {
        const check = gpa.deinit();
        std.debug.print("Gpa check = {any}\n", .{check});
    }
    const allocator = gpa.allocator();
    const data = try process_data(allocator);
    defer allocator.free(data);

    const stdout = std.io.getStdOut();
    defer stdout.close();

    const writter = stdout.writer();

    try writter.print("{s}\n", .{data});
}

fn process_data(allocator: std.mem.Allocator) ![]const u8 {
    var map = Data.init(allocator);
    defer map.deinit();

    // let's simulate that the string one and folder came from reading
    // a file or something that allocate the string to memory
    const one = try std.fmt.allocPrint(allocator, "{s}", .{"one"});
    // In this case we are going to free
    defer allocator.free(one);

    const folder = try std.fmt.allocPrint(allocator, "{s}", .{"/this/is/a/test"});
    defer allocator.free(folder);

    try map.put("state", one);
    try map.put("folder", folder);

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
    const string = try process_data(std.testing.allocator);
    defer std.testing.allocator.free(string);

    try std.testing.expect(std.mem.eql(u8, string, "{\"folder\":\"/this/is/a/test\",\"state\":\"one\"}"));
}
