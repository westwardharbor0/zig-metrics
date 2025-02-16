# zig-metrics
Prometheus metrics implemented using "Zig" and imagination.

Using ArenaAllocator to store all the heap data. 

# Install 

Fetch the module.
```
zig fetch --save "git+https://github.com/westwardharbor0/zig-metrics#v0.9.1"
```
Add to your `build.zig` 
```rust
const zig_metrics = b.dependency("zig-metrics", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zig-metrics", zig_metrics.module("zig-metrics"));
```

# Usage 

Metrics can be used separately as independent units or grouped to a registry. 

No matter the approach you can use a shared method `.write()` which will return the current state of metrics in a Prometheus format.

Example: 

```rust
// Zig version 0.14.0
const std = @import("std");
const heap = std.heap;
const metrics = @import("zig-metrics");


pub fn main() !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);  
    defer arena.deinit();

    // Create a registry.
    var r = metrics.Registry.init(arena.allocator());
    // Create a gauge metric.
    var g = metrics.Gauge.init(
        arena.allocator(),
        "test_example_gauge",
        "Test gauge desc",
    );
    // Create a counter metric.
    var c = metrics.Counter.init(
        arena.allocator(),
        "test_example_counter",
        "Test counter desc",
    );

    // Register metrics.
    try r.register(&g);
    try r.register(&c);

    // Work with metrics.
    try c.inc(.{}, 12.333);
    try c.inc(.{}, 1.343);
    try g.set(.{}, 222);

    // Generate output of the whole registry.
    const m = try r.write()
    // Free the output once we don't need it. 
    arena.allocator().free(m);
    // Print the output.
    std.log.debug("{s}", .{m});
}
```
