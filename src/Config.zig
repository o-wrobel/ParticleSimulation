pub const Config = @This();

const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const Vector2 = @import("Vector2");

const phys = @import("physics.zig");

const ParticleSet = phys.ParticleSet;
const Particle = phys.Particle;
const Physics = phys.Physics;

const deltaTime = rl.getFrameTime;

const sizes_amount = 7;

physics: Physics,
particles: Particles,
color_palette: ColorPalette = .init(),

pub const defaults = Config{
	.physics = .{
		.gravity = 1000,
		.wall_restitution = 0.95,
		.velocity_damping = 0.999,
	},
	.particles = .{
		.initial_count = 0,
		.size_factor = 5,
		.minimum_size = 10,
	},
};

pub const ColorPalette = struct {
	colors: [sizes_amount]rl.Color = @splat(rl.Color.white),

	pub fn init() ColorPalette {
		var palette: ColorPalette = .{};
		palette.colors[0] = .red;
		palette.colors[1] = .blue;
		palette.colors[2] = .green;
		palette.colors[3] = .yellow;
		palette.colors[4] = .violet;
		palette.colors[5] = .orange;
		return palette;
	}

	pub fn getColor(self: ColorPalette, index: usize) rl.Color {
		return self.colors[index];
	}
};

/// Slice of hex color strings, like #FF00FF
pub const ColorConfig = []const [7]u8;

pub const Particles = struct {
	initial_count: usize = 0,
	size_factor: f32,
	minimum_size: f32,
};

pub const ZonConfig = struct {
	physics: Physics = .{},
	particles: Particles = .{},
	// color_palette: ColorConfig,
};
