const std = @import("std");
const LinkedList = @import("LinkedList.zig").LinkedList;

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
			}
		}
		script = script[0..tot];
		return script;
	}

	fn _compileCount(instsp: *[]const BfInstTypePrimitive, instp: [2]BfInstTypePrimitive) i32 {
		var k: i32 = 0;

		while (instsp.*.len != 0 and (instsp.*[0] == instp[0] or instsp.*[0] == instp[1])) {
			if (instsp.*[0] == instp[0]) {
				k += 1;
			} else {
				k -= 1;
			}
			instsp.* = instsp.*[1..];
		}
		return k;
	}

	fn _compile(allocator: std.mem.Allocator, instsp: *[]const BfInstTypePrimitive) !BfInst {
		switch (instsp.*[0]) {
			.INCPTR, .DECPTR	=> { return BfInst{.PTR = _compileCount(instsp, .{.INCPTR, .DECPTR})}; },
			.INC, .DEC			=> { return BfInst{.AT = _compileCount(instsp, .{.INC, .DEC})}; },
			.OUT				=> { instsp.* = instsp.*[1..]; return .OUT; },
			.IN					=> { instsp.* = instsp.*[1..]; return .IN; },
			.OPEN				=> {
				instsp.* = instsp.*[1..];
				var inst =  BfInst{.WHILE = try _compileAux(allocator, instsp)};
				errdefer BfInst.destroy(&inst);
				if (instsp.*.len == 0)
					return BfError.SyntaxError;
				instsp.* = instsp.*[1..];
				return inst;
			},
			.CLOSE				=> unreachable,
		}
	}

	fn _compileAux(allocator: std.mem.Allocator, instsp: *[]const BfInstTypePrimitive) anyerror!BfScript {
		var script = BfScript.init(allocator);
		errdefer script.deinit();
		while (instsp.*.len != 0 and instsp.*[0] != .CLOSE) {
			var inst = try _compile(allocator, instsp);
			errdefer BfInst.destroy(&inst);
			try script.pushBack(inst);
		}
		return script;
	}

	pub fn compile(allocator: std.mem.Allocator, instsp: []const BfInstTypePrimitive) !BfScript {
		var instspcopy = instsp;
		var script = try _compileAux(allocator, &instspcopy);
		errdefer script.deinit();
		if (instspcopy.len != 0)
			return BfError.SyntaxError;
		return script;
	}
};

const BfInstType = enum {
	PTR,	// <>
	AT,		// +-
	OUT,	// .
	IN,		// ,
	WHILE,	// []
};

const BfScript = LinkedList(BfInst, BfInst.destroy);
const BfInst = union(BfInstType) {
	PTR: i32,			// <>
	AT: i32,			// +-
	OUT: void,			// .
	IN: void,			// ,
	WHILE: BfScript,	// []

	pub fn destroy(p: *anyopaque) void {
		const self: *@This() = @ptrCast(@alignCast(p));
		if (self.* == .WHILE) {
			std.debug.print("destroy subscript size : {d}\n", .{self.*.WHILE.size});
			self.*.WHILE.deinit();
		} else {
			std.debug.print("destroy : {any}\n", .{self.*});
		}
	}

	pub fn toStr(self: @This()) []const u8 {
		const buf = struct {
			var data: [1024]u8 = undefined;
		};

		return switch (self) {
			.PTR	=> |off| std.fmt.bufPrintZ(&buf.data, "ptr += {d};", .{off}) catch "",
			.AT	=> |off| std.fmt.bufPrintZ(&buf.data, "*ptr += {d};", .{off}) catch "",
			.OUT	=> "putchar(*ptr);",
			.IN	=> "*ptr = getchar();",
			.WHILE	=> "while (*ptr != 0) {",
		};
	}
};

fn _printScript(script: BfScript, tab: u32) void {
	var instp = script.head;

	while (instp) |inst| {
		instp = inst.next;
		if (inst.data == .WHILE) {
			std.debug.print("{s:[pad]}while (*ptr != 0) {{\n", .{.s = "", .pad = tab});
			_printScript(inst.data.WHILE, tab + 4);
			std.debug.print("{s:[pad]}}}\n", .{.s = "", .pad = tab});
		} else {
			std.debug.print("{s:[pad]}{[str]s}\n", .{.s = "", .pad = tab, .str = inst.data.toStr()});
		}
	}
}

pub fn printScript(script: BfScript) void {
	_printScript(script, 0);
}

const BfInterpreter = struct {
	const Self = @This();

	mem: [30000]u8 = [_]u8{0} ** 30000,
	ptr: usize = 0,
	script: ?*BfScript,
};

pub fn main() !void {
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	var instsp = try BfInstTypePrimitive.fromFile(allocator, std.io.getStdOut());
	defer allocator.free(instsp);
	var script = try BfInstTypePrimitive.compile(allocator, instsp);
	printScript(script);

}
