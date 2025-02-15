// Zig version 0.14.0
const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;

const metrics = @import("metrics.zig");

// ----------- Counter tests --------------

test "counter metric label add" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Counter.init(arena.allocator(), "test_counter", "Test counter desc");
    try c.addLabel("hostname");
    try testing.expectEqual(c.nm.labelNames.items.len, 1);
    try c.addLabel("domain");
    try testing.expectEqual(c.nm.labelNames.items.len, 2);
}

test "counter metric value recorded for labels" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Counter.init(arena.allocator(), "test_counter", "Test counter desc");
    try c.addLabel("hostname");
    try c.addLabel("ip");
    try c.inc(.{ "test.hostname", "1.1.1.1" }, 1);
    try c.inc(.{ "test.hostname", "1.1.1.2" }, 1);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.1"), 1);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.2"), 1);
}

test "counter metric labels not same" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Counter.init(arena.allocator(), "test_counter", "Test counter desc");
    try c.addLabel("hostname");
    try testing.expectError(
        metrics.MetricError.UnknownLabelSet,
        c.inc(.{ "test.hostname", "1.1.1.1" }, 1),
    );
}

test "counter metric counter negative value" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Counter.init(arena.allocator(), "test_counter", "Test counter desc");
    try c.addLabel("hostname");
    try testing.expectError(
        metrics.MetricError.CounterValueNegative,
        c.inc(.{"test.hostname"}, -1),
    );
}

test "counter metric non-string label value provided" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Counter.init(arena.allocator(), "test_counter", "Test counter desc");
    try c.addLabel("hostname");
    try testing.expectError(
        metrics.MetricError.LabelValuesNotStringArray,
        c.inc(.{1}, 1),
    );

    try testing.expectError(
        metrics.MetricError.LabelValuesNotStringArray,
        c.inc(1, 1),
    );
}

// ----------- Gauge tests --------------

test "gauge metric label add" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Gauge.init(arena.allocator(), "test_gauge", "Test gauge desc");
    try c.addLabel("hostname");
    try testing.expectEqual(c.nm.labelNames.items.len, 1);
    try c.addLabel("domain");
    try testing.expectEqual(c.nm.labelNames.items.len, 2);
}

test "gauge metric value inc recorded for labels" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Gauge.init(arena.allocator(), "test_gauge", "Test gauge desc");
    try c.addLabel("hostname");
    try c.addLabel("ip");
    try c.inc(.{ "test.hostname", "1.1.1.1" }, 1);
    try c.inc(.{ "test.hostname", "1.1.1.2" }, 1);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.1"), 1);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.2"), 1);
}

test "gauge metric value set recorded for labels" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Gauge.init(arena.allocator(), "test_gauge", "Test gauge desc");
    try c.addLabel("hostname");
    try c.addLabel("ip");
    try c.inc(.{ "test.hostname", "1.1.1.1" }, 2);
    try c.inc(.{ "test.hostname", "1.1.1.1" }, 2);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.1"), 4);
    try c.set(.{ "test.hostname", "1.1.1.1" }, 13);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.1"), 13);
    try c.set(.{ "test.hostname", "1.1.1.55" }, 3);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.55"), 3);
}

test "gauge metric value dec recorded for labels" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var c = metrics.Gauge.init(arena.allocator(), "test_gauge", "Test gauge desc");
    try c.addLabel("hostname");
    try c.addLabel("ip");
    try c.set(.{ "test.hostname", "1.1.1.1" }, 22);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.1"), 22);
    try c.set(.{ "test.hostname", "1.1.1.1" }, 13);
    try testing.expectEqual(c.nm.labelMap.get("test.hostname|1.1.1.1"), 13);
}

// ----------- Histogram tests --------------

test "histogram metric label add" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var h = metrics.Histogram.init(arena.allocator(), "test_histogram", "Test histogram desc");
    try h.addLabel("hostname");
    try testing.expectEqual(h.nm.labelNames.items.len, 1);
    try h.addLabel("ring");
    try testing.expectEqual(h.nm.labelNames.items.len, 2);
}

test "histogram metric value observe recorded for labels" {
    const ta = testing.allocator;
    var arena = heap.ArenaAllocator.init(ta);
    defer arena.deinit();
    var h = metrics.Histogram.init(
        arena.allocator(),
        "test_histogram",
        "Test histogram desc",
        .{ 0.1, 0.2, 0.3, 0.5, 1, 1.5, 2, 5 },
    );
    try h.addLabel("hostname");
    try h.addLabel("ip");
    try h.set(.{ "test.hostname", "1.1.1.1" }, 22);
    try testing.expectEqual(h.nm.labelMap.get("test.hostname|1.1.1.1"), 22);
    try h.set(.{ "test.hostname", "1.1.1.1" }, 13);
    try testing.expectEqual(h.nm.labelMap.get("test.hostname|1.1.1.1"), 13);
}
