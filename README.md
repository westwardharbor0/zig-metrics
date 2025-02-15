# zig-metrics
Zig prometheus metrics

```zig

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    defer arena.deinit();
    const allocator = arena.allocator();

    var rrr = Registry.init(allocator);

    var c = Counter.init(allocator, "test_metric_total", "test metrics description");
    try rrr.register(&c);
    try c.addLabel("hostname");
    try c.addLabel("region");
    try c.inc(.{ "test.com", "us-west-1" }, 2);
    try c.inc(.{ "test.com1", "us-west-2" }, 4);
    try c.inc(.{ "test.com1", "us-west-2" }, 4);
    try c.inc(.{ "test.com1", "true" }, 4);
    //const output = try c.write();
    //std.debug.print("{s}\n", .{output});

    //---------------------------------------------------------------------

    var d = Counter.init(allocator, "test_metric", "test metrics description");
    try rrr.register(&d);

    try d.inc(.{}, 2);
    try d.inc(.{}, 2000);

    //const output1 = try d.write();
    //std.debug.print("{s}\n", .{output1});

    //---------------------------------------------------------------------

    var g = Gauge.init(allocator, "test_metric_gauge", "test metrics gauge description");
    try rrr.register(&g);
    try g.inc(.{}, 2);
    try g.inc(.{}, 200);

    //var output2 = try g.write();
    //std.debug.print("{s}\n", .{output2});

    try g.dec(.{}, 200);

    //output2 = try g.write();
    //std.debug.print("{s}\n", .{output2});

    //---------------------------------------------------------------------

    var jj = try Histogram.init(
        allocator,
        "test_metric_histogram_like_af",
        "test histogram description",
        .{ 0.2, 0.3, 0.5, 0.7, 1, 1.5 },
    );

    try jj.addLabel("hostname");
    try jj.addLabel("region");

    try jj.observe(.{ "GET", "200" }, 9.9);
    try jj.observe(.{ "GET", "200" }, 9.9);
    try jj.observe(.{ "GET", "200" }, 9.9);
    try jj.observe(.{ "GET", "200" }, 9.9);
    try jj.observe(.{ "GET", "200" }, 0.9);
    try jj.observe(.{ "GET", "200" }, 0.3);
    try jj.observe(.{ "GET", "200" }, 0.1);
    try jj.observe(.{ "GET", "400" }, 0.1);
    try jj.observe(.{ "GET", "300" }, 0.1);
    try jj.observe(.{ "GET", "300" }, 20);

    //const output2 = try jj.write();
    //std.debug.print("{s}\n", .{output2});

    try rrr.register(&jj);
    std.debug.print("{d}\n", .{rrr.registered()});

    try jj.observe(.{ "GET", "300" }, 1000);

    const r = try rrr.write();
    std.debug.print("{s}\n", .{r});
}

```
