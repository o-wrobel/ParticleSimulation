const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");

const lpe = @import("little_physics_engine");
const Simulation = lpe.Simulation;
const Vector2 = lpe.Vector2;

const Particle = Simulation.Particle;
const Box = Simulation.Box;

const Config = @import("Config.zig");
const ZonConfig = Config.ZonConfig;

const deltaTime = rl.getFrameTime;

inline fn toVector2(vector: rl.Vector2) Vector2 {
	return Vector2.init(vector.x, vector.y);
}

/// Returns a particle buffer with particles placed randomly within the box
fn getParticleSet(config: Config, random: std.Random, allocator: std.mem.Allocator) ![]Particle {
	var particles = allocator.alloc(Particle, config.particles.initial_count)
		catch |err| {
			std.log.err("Failed to allocate particles: {}", .{err});
			return &.{};
		};
	for (0..config.particles.initial_count) |i| {
		const size = random.intRangeAtMost(i8, 1, 6);
		var particle = getParticle(size, config);
		particle.pos = .init(
			@floatFromInt(random.intRangeAtMost(i32, 100, 700)),
			@floatFromInt(random.intRangeAtMost(i32, 100, 500)),
		);
		particle.velocity = .init(
			@floatFromInt(random.intRangeAtMost(i32, -100, 100)),
			0
		);
		particles[i] = particle;
	}
	return particles;
}

/// Returns a particle with a size determined by the given config
fn getParticle(size: i8, config: Config) Particle {
	return Particle{
		.radius = config.particles.minimum_size + config.particles.size_factor * size,
	};
}

fn getColorForParticle(config: Config, size: i8) rl.Color {
	return config.color_palette.getColor(@intCast(size-1));
}

fn drawParticle(p: Particle, color: rl.Color) void {
	rl.drawCircleV(
		.initVec(p.pos.data),
		p.radius,
		color
	);
}

fn drawParticlePreview(p: Particle, color: rl.Color) void {
	var preview_color = color;
	preview_color.a = 100;
	rl.drawCircleV(
		.initVec(p.pos.data),
		p.radius,
		preview_color
	);
}

fn drawParticles(particles: []Particle, colors: []rl.Color) void {
	for (particles, colors) |p, color| {
		drawParticle(p, color);
	}
}

fn drawBox(box: Box, color: rl.Color) void {
	rl.drawRectangle(
		@trunc(box.x),
		@trunc(box.y),
		@trunc(box.width),
		@trunc(box.height),
		color
	);
}

/// Loads and returns a config from a file
fn loadConfig(filename: []const u8, io: std.Io, allocator: std.mem.Allocator) !Config {
    const cwd = std.Io.Dir.cwd();
    const string = try std.Io.Dir.readFileAlloc(cwd, io, filename, allocator, .unlimited);
    defer allocator.free(string);
    const string_sentinel = try allocator.dupeSentinel(u8, string, 0);
    defer allocator.free(string_sentinel);

    var diag: std.zon.parse.Diagnostics = .{};
    defer diag.deinit(allocator);
    const zon = std.zon.parse.fromSlice(ZonConfig, allocator, string_sentinel, &diag, .{}) catch |err| {
        std.debug.print("Failed to parse config.zon:\n{}\n", .{diag});
        return err;
    };
    return Config.zonToConfig(zon);
}

fn drawFPS(color: rl.Color, pos_x: i32, pos_y: i32) void {
	var string: [12]u8 = undefined;
	const formatted = std.fmt.bufPrint(&string, "{} FPS", .{rl.getFPS()})
		catch unreachable;
	string[formatted.len] = 0;
	const string_sentinel: [:0]const u8 = string[0..formatted.len :0];
	rl.drawText(string_sentinel, pos_x, pos_y, 20, color);
}

fn addParticle(simulation: *Simulation, particle: Particle, colors: std.ArrayList(rl.Color), allocator: std.mem.Allocator) !void {
	try simulation.addParticle(particle, allocator);
	colors.append(allocator, .gray);
}

pub fn main(init: std.process.Init) !void {
	const allocator = init.gpa;
	const io = init.io;
	const random = (std.Random.IoSource{.io = io}).interface();

	// Engine Setup
	const config = if (builtin.os.tag == .emscripten)
		Config.defaults
		else try loadConfig("config.zon", io, allocator);

	const box: Box = .{
		.x = 40,
		.y = 40,
		.width = 800 - 80,
		.height = 800 - 80,
	};

	var simulation = try Simulation.init(box, allocator);
	defer simulation.deinit(allocator);

	if (config.particles.initial_count > 0) {
		const particles = try getParticleSet(config, random, allocator);
		defer allocator.free(particles);
		for (particles) |particle| {
			try simulation.addParticle(particle, allocator);
		}
	}

	var colors: std.ArrayList(rl.Color) = try .initCapacity(allocator, config.particles.initial_count);
	defer colors.deinit(allocator);

	var particle_size: i8 = 1;

	rl.initWindow(800, 800, "Particle Simulation");
	defer rl.closeWindow();
	rl.setTargetFPS(60);
	rl.setMouseCursor(.pointing_hand);

	while (!rl.windowShouldClose()) {
		// Update
		const mouse_pos = toVector2(rl.getMousePosition());

		const mouse_wheel = rl.getMouseWheelMove();
		particle_size += @trunc(mouse_wheel);
		particle_size = std.math.clamp(particle_size, 1, 6);

		var particle_to_be_placed = getParticle(particle_size, config);
		particle_to_be_placed.pos = mouse_pos;
		const color = getColorForParticle(config, particle_size);

		if (rl.isMouseButtonPressed(.left)) {
			simulation.addParticle(particle_to_be_placed, allocator)
				catch |err| {
					std.log.err("Failed to add particle: {}", .{err});
				};
			colors.append(allocator, color)
				catch |err| {
					std.log.err("Failed to add color: {}", .{err});
				};
			std.log.debug("Added particle | pos: {f}, radius: {}", .{particle_to_be_placed.pos, particle_to_be_placed.radius});
		}

		if (rl.isKeyPressed(.r)) {
			simulation.reset(allocator)
				catch |err| {
					std.log.err("Failed to reset simulation: {}", .{err});
				};
			colors.deinit(allocator);
			colors = std.ArrayList(rl.Color).initCapacity(allocator, 0)
				catch |err| {
					std.log.err("Failed to reset simulation: {}", .{err});
					return ;
				};
		}

		simulation.update(config.physics, deltaTime());

		// Drawing
		rl.beginDrawing();
		rl.clearBackground(.white);

		drawBox(box, .black);
		drawParticles(simulation.particles.items, colors.items);
		drawParticlePreview(particle_to_be_placed, getColorForParticle(config, particle_size));
		drawFPS(.black, 40, 10);

		rl.endDrawing();
	}
}
