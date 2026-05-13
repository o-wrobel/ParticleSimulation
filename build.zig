const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
	// TODO: Maybe place this somewhere else. Emscripten definitions require this to be before them
	const run_step = b.step("run", "Run the app");

	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const lpe_dep = b.dependency("little_physics_engine", .{
		.target = target,
		.optimize = optimize,
	});
	const lpe_mod = lpe_dep.module("little_physics_engine");

	// Raylib import
	const raylib_dep = b.dependency("raylib_zig", .{
		.target = target,
		.optimize = optimize,
	});

	const raylib = raylib_dep.module("raylib"); // main raylib module
	const raygui = raylib_dep.module("raygui"); // raygui module
	const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

	const exe_mod = b.createModule(.{
		.root_source_file = b.path("src/main.zig"),
		.target = target,
		.optimize = optimize,
	});

	if (target.query.os_tag == .emscripten) {
		const emsdk = rlz.emsdk;
		const wasm = b.addLibrary(.{
			.name = "particle_simulation",
			.root_module = exe_mod,
		});

		// Import little_physics_engine module
		wasm.root_module.addImport("little_physics_engine", lpe_mod);

		// Import raylib modules
		wasm.root_module.addImport("raylib", raylib);
		wasm.root_module.addImport("raygui", raygui);

		const install_dir: std.Build.InstallDir = .{ .custom = "web" };
		const emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize });
		const emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize });

		const emcc_step = emsdk.emccStep(b, raylib_artifact, wasm, .{
			.optimize = optimize,
			.flags = emcc_flags,
			.settings = emcc_settings,
			.install_dir = install_dir,
			.shell_file_path = b.path("src/shell.html"),
		});
		b.getInstallStep().dependOn(emcc_step);

		const html_filename = try std.fmt.allocPrint(b.allocator, "{s}.html", .{wasm.name});

		// Renaming physics_sim.html -> index.html
		const rename_step = b.addSystemCommand(&.{ "mv", "-f" });
		rename_step.addArg(b.getInstallPath(install_dir, html_filename));
		const index_html_path = b.getInstallPath(install_dir, "index.html");
		rename_step.addArg(index_html_path);
		rename_step.step.dependOn(emcc_step);
		b.getInstallStep().dependOn(&rename_step.step);

		const emrun_step = emsdk.emrunStep(
			b,
			index_html_path,
			&.{},
		);

		emrun_step.dependOn(&rename_step.step);
		run_step.dependOn(emrun_step);

		// `zig build zip` — bundle the web folder into a zip (relative paths)
		const zip_step = b.step("zip", "Create zig-out/web.zip from the web build");
		const web_dir = b.getInstallPath(install_dir, "");
		const zip_out = b.getInstallPath(.prefix, "web.zip");
		const zip_cmd = b.addSystemCommand(&.{ "sh", "-c" });
		zip_cmd.addArg(try std.fmt.allocPrint(b.allocator, "cd '{s}' && zip -r '{s}' .", .{ web_dir, zip_out }));
		zip_cmd.step.dependOn(b.getInstallStep());
		zip_step.dependOn(&zip_cmd.step);
	} else {
		const exe = b.addExecutable(.{
			.name = "physics_test",
			.root_module = exe_mod
		});

		// Import little_physics_engine module
		exe.root_module.addImport("little_physics_engine", lpe_mod);

		// Import and Link raylib
		exe.root_module.linkLibrary(raylib_artifact);
		exe.root_module.addImport("raylib", raylib);
		exe.root_module.addImport("raygui", raygui);

		// This declares intent for the executable to be installed into the
		// install prefix when running `zig build` (i.e. when executing the default
		// step). By default the install prefix is `zig-out/` but can be overridden
		// by passing `--prefix` or `-p`.
		b.installArtifact(exe);

		// This creates a RunArtifact step in the build graph. A RunArtifact step
		// invokes an executable compiled by Zig. Steps will only be executed by the
		// runner if invoked directly by the user (in the case of top level steps)
		// or if another step depends on it, so it's up to you to define when and
		// how this Run step will be executed. In our case we want to run it when
		// the user runs `zig build run`, so we create a dependency link.
		const run_cmd = b.addRunArtifact(exe);
		run_step.dependOn(&run_cmd.step);

		// By making the run step depend on the default step, it will be run from the
		// installation directory rather than directly from within the cache directory.
		run_cmd.step.dependOn(b.getInstallStep());

		// This allows the user to pass arguments to the application in the build
		// command itself, like this: `zig build run -- arg1 arg2 etc`
		if (b.args) |args| {
			run_cmd.addArgs(args);
		}
	}
}
