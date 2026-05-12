const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const Vector2 = @import("Vector2");

const physics = @import("physics.zig");

const ParticleSet = physics.ParticleSet;
const Particle = physics.Particle;
const PhysicsConfig = physics.Physics;

const Config = @import("Config.zig");
const ColorPalette = Config.ColorPalette;

const deltaTime = rl.getFrameTime;

var particle_size: i8 = 1;
const minimum_size = 10;
const size_factor = 10;
const sizes_amount = 7;

inline fn toRaylibVector(vector: Vector2) rl.Vector2 {
	return .init(vector.x(), vector.y());
}

inline fn toVector2(vector: rl.Vector2) Vector2 {
	return Vector2.init(vector.x, vector.y);
}

fn setColorPalette(particles: ParticleSet, palette: ColorPalette) void {
	for (particles.list.items) |*p| {
		p.color = palette.getColor(@divTrunc(@as(usize, @trunc(p.radius)) - minimum_size, size_factor));
	}
}

fn getFancyParticle(size: i8, palette: ColorPalette) Particle {
	const color = palette.getColor(@intCast(size-1));
	return Particle{
		.radius = minimum_size + size_factor * size,
		.color = color,
	};
}

pub fn drawParticle(p: Particle) void {
	rl.drawCircleV(
		toRaylibVector(p.pos),
		p.radius,
		p.color
	);
		// if (self.collided) rl.Color.white else self.color);
}

fn drawParticles(particles: ParticleSet) void {
	for (particles.list.items) |p| {
		drawParticle(p);
	}
}

pub fn drawParticlePreview(p: Particle) void {
	var color = p.color;
	color.a = 100;
	rl.drawCircleV(
		toRaylibVector(p.pos),
		p.radius,
		color
	);
		// if (self.collided) rl.Color.white else self.color);
}

/// Returns the config. On web, uses hardcoded defaults (no filesystem).
fn loadConfig(filename: []const u8, io: std.Io, allocator: std.mem.Allocator) !Config {
    if (builtin.os.tag == .emscripten) {
        return Config.defaults;
    } else {
        // Native: read from disk
        const cwd = std.Io.Dir.cwd();
        const string = try std.Io.Dir.readFileAlloc(cwd, io, filename, allocator, .unlimited);
        defer allocator.free(string);
        const string_sentinel = try allocator.dupeSentinel(u8, string, 0);
        defer allocator.free(string_sentinel);
        return try std.zon.parse.fromSlice(Config, allocator, string_sentinel, null, .{});
    }
}

pub fn main(init: std.process.Init) !void {
	const allocator = init.gpa;
	const io = init.io;
	const random = (std.Random.IoSource{.io = io}).interface();

	// Engine Setup
	const config = try loadConfig("config.zon", io, allocator);

	var particles: ParticleSet = try .init(config.particles.initial_count, random, allocator);
	defer particles.deinit(allocator);

	setColorPalette(particles, config.color_palette);

	const box: rl.Rectangle = .init(40, 40, 800 - 80, 800 - 80);

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

		var particle_to_be_placed = getFancyParticle(particle_size, config.color_palette);
		particle_to_be_placed.pos = mouse_pos;

		if (rl.isMouseButtonPressed(.left)) {
			try particles.addParticle(particle_to_be_placed, allocator);
		}

		if (rl.isKeyPressed(.r)) try particles.reset(allocator);

		particles.update(box, config.physics);

		// Drawing
		rl.beginDrawing();
		rl.clearBackground(.white);

		// drawRectangleLinesOutside(box, 10, .blue);
		rl.drawRectangleRec(box, .black);
		drawParticles(particles);
		drawParticlePreview(particle_to_be_placed);
		rl.drawFPS(40, 10);

		rl.endDrawing();
	}
}
