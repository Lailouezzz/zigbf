const std = @import("std");

pub fn build(b: *std.build.Builder) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
	const exe = b.addExecutable(.{
		.name = "zigbf",
		.root_source_file = .{ .path = "main.zig" },
		.target = target,
		.optimize = optimize,
	});
	const run_cmd = b.addRunArtifact(exe);
	if (b.args) |args| {
		run_cmd.addArgs(args);
	}
	const run_step = b.step("run", "Run zigbf");
	run_step.dependOn(&run_cmd.step);
	const install_artifact = b.addInstallArtifact(exe, .{});
	b.getInstallStep().dependOn(&install_artifact.step);
}
