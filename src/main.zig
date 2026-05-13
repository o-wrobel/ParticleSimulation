const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const Vector2 = @import("Vector2");

const physics = @import("physics.zig");

const Simulation = physics.Simulation;
const Particle = physics.Particle;
const Box = physics.Box;

const PhysicsConfig = physics.Constants;

const Config = @import("Config.zig");
const ZonConfig = Config.ZonConfig;
const ColorPalette = Config.ColorPalette;

const deltaTime = rl.getFrameTime;

inline fn toRaylibVector(vector: Vector2) rl.Vector2 {
	return .init(vector.x(), vector.y());
}

inline fn toVector2(vector: rl.Vector2) Vector2 {
	return Vector2.init(vector.x, vector.y);
}

/// Returns a particle buffer with particles placed randomly within the box.
fn getParticleSet(config: Config, random: std.Random, allocator: std.mem.Allocator) ![]Particle {
	var particles = try allocator.alloc(Particle, config.particles.initial_count);
	for (0..config.particles.initial_count) |i| {
		const size = random.intRangeAtMost(i8, 1, 6);
		var particle = getParticleWithPalette(size, config);
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

/// Returns a particle with a color from the palette based on the size.
fn getParticleWithPalette(size: i8, config: Config) Particle {
	const color = config.color_palette.getColor(@intCast(size-1));
	return Particle{
		.radius = config.particles.minimum_size + config.particles.size_factor * size,
		.color = color,
	};
}

fn drawParticle(p: Particle) void {
	rl.drawCircleV(
		toRaylibVector(p.pos),
		p.radius,
		p.color
	);
		// if (self.collided) rl.Color.white else self.color);
}

fn drawParticles(particles: []Particle) void {
	for (particles) |p| {
		drawParticle(p);
	}
}

fn drawParticlePreview(p: Particle) void {
	var color = p.color;
	color.a = 100;
	rl.drawCircleV(
		toRaylibVector(p.pos),
		p.radius,
		color
	);
		// if (self.collided) rl.Color.white else self.color);
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

fn drawFPS(color: rl.Color, pos_x: i32, pos_y: i32, allocator: std.mem.Allocator) !void {
	// TODO: Remove allocations with fixed buffer
	const string = try std.fmt.allocPrint(allocator, "{} FPS", .{rl.getFPS()});
	const string_sentinel = try allocator.dupeSentinel(u8, string, 0);
	defer allocator.free(string);
	defer allocator.free(string_sentinel);
	rl.drawText(string_sentinel, pos_x, pos_y, 20, color);
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

		var particle_to_be_placed = getParticleWithPalette(particle_size, config);
		particle_to_be_placed.pos = mouse_pos;

		if (rl.isMouseButtonPressed(.left)) {
			try simulation.addParticle(particle_to_be_placed, allocator);
		}

		if (rl.isKeyPressed(.r)) try simulation.reset(allocator);

		simulation.update(config.physics);

		// Drawing
		rl.beginDrawing();
		rl.clearBackground(.white);

		drawBox(box, .black);
		drawParticles(simulation.particles.items);
		drawParticlePreview(particle_to_be_placed);
		try drawFPS(.black, 40, 10, allocator);

		rl.endDrawing();
	}
}
