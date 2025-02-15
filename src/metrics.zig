// Zig version 0.14.0
const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;

pub const MetricError = error{
    UnknownLabelSet,
    LabelValueNotString,
    LabelValuesNotStringArray,
    CounterValueNegative,
};

const NumberMetric = struct {
    allocator: mem.Allocator,
    labelMap: std.StringHashMap(f64),
    labelNames: std.ArrayList([]const u8),
    name: []const u8,
    desc: []const u8,
    metricType: []const u8,

    pub fn init(allocator: mem.Allocator, name: []const u8, desc: []const u8, metricType: []const u8) @This() {
        return .{
            .allocator = allocator,
            .name = name,
            .desc = desc,
            .labelNames = std.ArrayList([]const u8).init(allocator),
            .labelMap = std.StringHashMap(f64).init(allocator),
            .metricType = metricType,
        };
    }
    fn labelKeyGen(self: *@This(), labelValues: [][]const u8) ![]const u8 {
        var labeled = std.ArrayList([]const u8).init(self.allocator);
        defer labeled.deinit();

        for (labelValues, 1..) |labelVal, index| {
            try labeled.append(labelVal);
            if (index != labelValues.len) {
                try labeled.append("|");
            }
        }

        return std.mem.concat(self.allocator, u8, labeled.items) catch unreachable;
    }

    fn labelKey(self: *@This(), labelValues: anytype) ![]const u8 {
        var lv = std.ArrayList([]const u8).init(self.allocator);
        defer lv.deinit();

        const lvTypeName = @typeName(@TypeOf(labelValues));
        if (comptime !mem.eql(u8, lvTypeName, "@TypeOf(.{})") and !mem.startsWith(u8, lvTypeName, "struct{comptime *const ")) {
            return MetricError.LabelValuesNotStringArray;
        }

        inline for (labelValues) |val| {
            const typeName = @typeName(@TypeOf(val));
            if (!comptime mem.startsWith(u8, typeName, "*const [")) {
                return MetricError.LabelValueNotString;
            }
            try lv.append(val);
        }

        if (lv.items.len != self.labelNames.items.len) {
            return error.UnknownLabelSet;
        }

        return try self.labelKeyGen(lv.items);
    }

    pub fn inc(self: *@This(), labelValues: anytype, amount: f64) !void {
        const lk = try self.labelKey(labelValues);
        try self.keyInc(lk, amount);
    }

    pub fn set(self: *@This(), labelValues: anytype, amount: f64) !void {
        const lk = try self.labelKey(labelValues);
        try self.labelMap.put(lk, amount);
    }

    pub fn write(self: *@This()) ![]u8 {
        var arrList = std.ArrayList(u8).init(self.allocator);
        errdefer arrList.deinit();

        try arrList.writer().print("#HELP {s}\n", .{self.desc});
        try arrList.writer().print("#TYPE {s} {s}\n", .{ self.name, self.metricType });

        var it = self.labelMap.iterator();
        if (self.labelNames.items.len == 0) {
            try arrList.writer().print(
                "{s} {d}\n",
                .{ self.name, self.labelMap.get("").? },
            );
            return arrList.items;
        }

        while (it.next()) |key| {
            var spliced = mem.splitSequence(u8, key.key_ptr.*, "|");
            var counter: usize = 0;
            try arrList.writer().print(
                "{s}{{",
                .{self.name},
            );
            while (spliced.next()) |subPart| : (counter += 1) {
                try arrList.writer().print(
                    "{s}=\"{s}\",",
                    .{
                        self.labelNames.items[counter],
                        subPart,
                    },
                );
            }
            _ = arrList.pop();

            try arrList.writer().print(
                "}} {d}\n",
                .{
                    self.labelMap.get(key.key_ptr.*).?,
                },
            );
        }

        return arrList.items;
    }

    fn keyInc(self: *@This(), key: []const u8, amount: f64) !void {
        if (self.labelMap.get(key)) |value| {
            const newVal = value + amount;
            try self.labelMap.put(key, newVal);
        } else {
            try self.labelMap.put(key, amount);
        }
    }
};

pub const Gauge = struct {
    nm: NumberMetric,

    pub fn init(allocator: mem.Allocator, name: []const u8, desc: []const u8) @This() {
        return .{ .nm = NumberMetric.init(allocator, name, desc, "gauge") };
    }

    pub fn inc(self: *@This(), labelValues: anytype, amount: f64) !void {
        try self.nm.inc(labelValues, amount);
    }

    pub fn dec(self: *@This(), labelValues: anytype, amount: f64) !void {
        try self.nm.inc(labelValues, -amount);
    }

    pub fn set(self: *@This(), labelValues: anytype, amount: f64) !void {
        try self.nm.set(labelValues, amount);
    }

    pub fn addLabel(self: *@This(), name: []const u8) !void {
        try self.nm.labelNames.append(name);
    }

    pub fn write(self: *@This()) ![]u8 {
        return try self.nm.write();
    }
};

pub const Counter = struct {
    nm: NumberMetric,

    pub fn init(allocator: mem.Allocator, name: []const u8, desc: []const u8) @This() {
        return .{ .nm = NumberMetric.init(allocator, name, desc, "counter") };
    }

    pub fn inc(self: *@This(), labelValues: anytype, amount: f64) !void {
        if (amount < 0) {
            return MetricError.CounterValueNegative;
        }

        try self.nm.inc(labelValues, amount);
    }

    pub fn addLabel(self: *@This(), name: []const u8) !void {
        try self.nm.labelNames.append(name);
    }

    pub fn write(self: *@This()) ![]u8 {
        return try self.nm.write();
    }
};

pub const Histogram = struct {
    buckets: std.ArrayList(f64),
    count: u64 = 0,
    sum: f64 = 0,
    nm: NumberMetric,

    pub fn init(allocator: mem.Allocator, name: []const u8, desc: []const u8, buckets: anytype) !@This() {
        var bucketsF = std.ArrayList(f64).init(allocator);
        inline for (buckets) |bucketVal| {
            try bucketsF.append(bucketVal);
        }

        var s = NumberMetric.init(allocator, name, desc, "histogram");
        try s.labelNames.append("len");

        return .{ .buckets = bucketsF, .nm = s };
    }

    pub fn observe(self: *@This(), labelValues: anytype, amount: f64) !void {
        var added = false;

        self.count += 1;
        self.sum += amount;

        for (self.buckets.items) |bucketVal| {
            if (bucketVal > amount) {
                const sVal = try std.fmt.allocPrint(self.nm.allocator, "{d}", .{bucketVal});
                defer self.nm.allocator.free(sVal);
                try self.incLens(labelValues, sVal, 1);
                added = true;
            }
        }

        if (added) {
            return;
        }

        try self.incLens(labelValues, "+Inf", 1);
    }

    fn labelKey(self: *@This(), labelValues: anytype) ![]const u8 {
        var lv = std.ArrayList([]const u8).init(self.nm.allocator);
        defer lv.deinit();

        inline for (labelValues) |val| {
            const typeName = @typeName(@TypeOf(val));
            if (!comptime std.mem.startsWith(u8, typeName, "*const [")) {
                return MetricError.LabelValueNotString;
            }
            try lv.append(val);
        }

        if (lv.items.len != (self.nm.labelNames.items.len - 1)) {
            return error.UnknownLabelSet;
        }

        return try self.nm.labelKeyGen(lv.items);
    }

    fn incLens(self: *@This(), labelValues: anytype, len: []const u8, amount: f64) !void {
        const lk = try self.labelKey(labelValues);

        var arrList = std.ArrayList(u8).init(self.nm.allocator);
        try arrList.appendSlice(len);
        try arrList.appendSlice("|");
        try arrList.appendSlice(lk);

        const key = arrList.items;
        try self.nm.keyInc(key, amount);
    }

    pub fn addLabel(self: *@This(), name: []const u8) !void {
        try self.nm.labelNames.append(name);
    }

    pub fn write(self: *@This()) ![]u8 {
        var arrList = std.ArrayList(u8).init(self.nm.allocator);
        const result = try self.nm.write();

        try arrList.appendSlice(result);
        try arrList.writer().print("{s}_count {d}\n", .{ self.nm.name, self.count });
        try arrList.writer().print("{s}_sum {d}\n", .{ self.nm.name, self.sum });

        return arrList.items;
    }
};

pub const Registry = struct {
    allocator: std.mem.Allocator,
    counters: std.ArrayList(*Counter),
    gauges: std.ArrayList(*Gauge),
    histograms: std.ArrayList(*Histogram),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .allocator = allocator,
            .counters = std.ArrayList(*Counter).init(allocator),
            .gauges = std.ArrayList(*Gauge).init(allocator),
            .histograms = std.ArrayList(*Histogram).init(allocator),
        };
    }
    pub fn register(self: *@This(), metric: anytype) !void {
        const T = @TypeOf(metric);
        switch (T) {
            *Counter => try self.counters.append(metric),
            *Gauge => try self.gauges.append(metric),
            *Histogram => try self.histograms.append(metric),
            else => @compileError("not implemented for " ++ @typeName(T)),
        }
    }

    pub fn registered(self: *@This()) usize {
        return self.counters.items.len + self.gauges.items.len + self.histograms.items.len;
    }

    pub fn write(self: @This()) ![]const u8 {
        var arrList = std.ArrayList(u8).init(self.allocator);

        for (self.counters.items) |m| {
            try arrList.appendSlice("\n");
            try arrList.appendSlice(try m.write());
        }
        try arrList.appendSlice("\n");

        for (self.gauges.items) |m| {
            try arrList.appendSlice("\n");
            try arrList.appendSlice(try m.write());
        }
        try arrList.appendSlice("\n");

        for (self.histograms.items) |m| {
            try arrList.appendSlice("\n");
            try arrList.appendSlice(try m.write());
        }
        try arrList.appendSlice("\n");

        return arrList.items;
    }
};
