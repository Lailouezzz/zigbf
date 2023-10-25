const std = @import("std");

pub fn LinkedList(comptime T: type, comptime destroycb: ?*const fn (self: *anyopaque) void) type {
	return struct {
		const Self = @This();

		pub const Elem = struct {
			prev: ?*Elem = null,
			next: ?*Elem = null,
			data: T = undefined,
		};

		head: ?*Elem = null,
		tail: ?*Elem = null,
		size: usize = 0,
		allocator: std.mem.Allocator = undefined,

		pub fn init(allocator: std.mem.Allocator) Self {
			return Self{ .allocator = allocator };
		}

		pub fn deinit(self: *Self) void {
			var ptr = self.head;

			while (ptr) |elem| {
				ptr = elem.next;
				self._destroyElem(elem);
			}
		}

		fn _destroyElem(self: *Self, elem: *Elem) void {
			if (destroycb) |destroy| {
				destroy(&elem.data);
			}
			self.allocator.destroy(elem);
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

		pub fn popBack(self: *Self) ?T {
			if (self.tail) |tail| {
				const data = tail.data;
				defer self._destroyElem(tail);
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
