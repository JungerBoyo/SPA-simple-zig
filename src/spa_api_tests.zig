const std = @import("std");


const SpaApi = @import("spa_api.zig");

test "spa-api#0" {
    try std.testing.expectEqual(@as(c_int, 0), SpaApi.spaInit("../../cs_src/test.simple"));
    try std.testing.expectEqual(@as(c_int, 0), SpaApi.spaDeinit());
}