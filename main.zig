const std = @import("std");

const BfError = error {
	SyntaxError,
	PointerOutOfRange,
};

const buffer_size = 4096;

pub fn readContent(allocator: std.mem.Allocator, file: std.fs.File) ![]u8 {
	var content: []u8 = try allocator.alloc(u8, buffer_size);
	errdefer allocator.free(content);
	var tot: usize = 0;

	while (true) {
		if (content.len == tot)
			content = try allocator.realloc(content, content.len * 2);
		const readed = try file.read(content[tot..]);
		if (readed == 0)
			break;
		tot += readed;
	}
	return content[0..tot];
}

const BfInstTypePrimitive = enum {
	INCPTR,	// >
	DECPTR,	// <
	INC,	// +
	DEC,	// -
	OUT,	// .
	IN,		// ,
	OPEN,	// [
	CLOSE,	// ]

	pub fn fromChar(c: u8) ?BfInstTypePrimitive {
		return switch (c) {
			'>' => .INCPTR,
			'<' => .DECPTR,
			'+' => .INC,
			'-' => .DEC,
			'.' => .OUT,
			',' => .IN,
			'[' => .OPEN,
			']' => .CLOSE,
			else => null,
		};
	}

	pub fn fromFile(allocator: std.mem.Allocator, file: std.fs.File) ![]BfInstTypePrimitive {
		var content = try readContent(allocator, file);
		defer allocator.free(content);
		var script: []BfInstTypePrimitive = try allocator.alloc(BfInstTypePrimitive, 1);
		var tot: usize = 0;

		for (content) |c| {
			if (BfInstTypePrimitive.fromChar(c)) |inst| {
				if (script.len == tot)
					script = try allocator.realloc(script, script.len * 2);
				script[tot] = inst;
				tot += 1;
				std.debug.print("{}\n", .{inst});
			}
		}
		script = script[0..tot];
		return script;
	}

	pub fn compile(allocator: std.mem.Allocator, instsp: []BfInstTypePrimitive) !BfScript {
		var script = try BfScript.init(allocator);
		_ = script;
		_ = instsp;
		return .{};
	}
};

const BfInstType = enum {
	PTR,	// <>
	AT,		// +-
	OUT,	// .
	IN,		// ,
	WHILE,	// []
};

const BfScript = LinkedList(BfInst, null);

const BfInst = union(BfInstType) {
	PTR: i32,			// <>
	AT: i32,			// +-
	OUT: void,			// .
	IN: void,			// ,
	WHILE: BfScript,	// []
};

fn LinkedList(comptime T: type, comptime destroycb: ?*const fn (self: *T) void) type {
	return struct {
		const Self = @This();

		const Elem = struct {
			prev: ?*Elem = null,
			next: ?*Elem = null,
			data: T = undefined,
		};

		head: ?*Elem = null,
		tail: ?*Elem = null,
		size: usize = 0,
		allocator: std.mem.Allocator = undefined,

		pub fn init(allocator: std.mem.Allocator) !Self {
			return Self{ .allocator = allocator };
		}

		pub fn deinit(self: *Self) void {
			var ptr = self.head;

			while (ptr) |elem| {
				ptr = elem.next;
				if (destroycb) |destroy|
					destroy(&elem.data);
				self.allocator.destroy(elem);
			}
		}

		pub fn pushBack(self: *Self, data: T) !void {
			var elem = try self.allocator.create(Elem);

			elem.* = .{
				.data = data,
				.prev = self.tail,
			};
			if (self.tail) |*t| {
				t.*.next = elem;
				t.* = elem;
			} else {
				self.head = elem;
				self.tail = elem;
			}
			self.size += 1;
		}

		pub fn popBack(self: *Self) !?T {
			if (self.tail) |tail| {
				const data = tail.data;
				defer self.allocator.destroy(tail);
				self.tail = tail.prev;
				if (self.tail) |t| {
					t.next = null;
				} else {
					self.head = null;
				}
				self.size -= 1;
				return data;
			} else {
				return null;
			}
		}
	};
}

const BfInterpreter = struct {
	const Self = @This();

	mem: [30000]u8 = [_]u8{0} ** 30000,
	ptr: usize = 0,
	script: ?*BfScript,

	fn interpretAux(self: *Self, startip: usize) !usize {
		_ = self;
		_ = startip;
		return 0;
	}

	pub fn interpret(self: *Self) !void {
		if (try self.interpretAux(0) != self.script.len)
			return BfError.SyntaxError;
	}
};

pub fn main() !void {
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	var instsp = try BfInstTypePrimitive.fromFile(allocator, std.io.getStdOut());
	defer allocator.free(instsp);
	var script = try BfInstTypePrimitive.compile(allocator, instsp);
	_ = script;
}
