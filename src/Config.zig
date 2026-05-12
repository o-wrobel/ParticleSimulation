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

const sizes_amount = 6;

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

	pub fn fromHex(hex_colors: ColorConfig) ColorPalette {
		var palette: ColorPalette = .{};
		for (hex_colors, 0..) |hex, i| {
			palette.colors[i] = .{
				.r = @intCast((hex >> 16) & 0xFF),
				.g = @intCast((hex >> 8) & 0xFF),
				.b = @intCast(hex & 0xFF),
				.a = 0xFF,
			};
		}
		return palette;
	}

	pub fn getColor(self: ColorPalette, index: usize) rl.Color {
		return self.colors[index];
	}
};

/// Array of hex color values, like 0xFF00FF
pub const ColorConfig = [sizes_amount]u32;

pub const Particles = struct {
	initial_count: usize = 0,
	size_factor: f32,
	minimum_size: f32,
};

pub const ZonConfig = struct {
	physics: Physics,
	particles: Particles,
	colors: ColorConfig,
};

pub fn zonToConfig(zon: ZonConfig) Config {
	return Config{
		.physics = zon.physics,
		.particles = zon.particles,
		.color_palette = ColorPalette.fromHex(zon.colors),
	};
}
