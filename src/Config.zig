pub const Config = @This();

const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const Vector2 = @import("Vector2");

const Simulation = @import("Simulation.zig");

const Particle = Simulation.Particle;
const Physics = Simulation.Constants;

const deltaTime = rl.getFrameTime;

const sizes_amount = 6;

physics: Physics,
particles: Particles,
color_palette: ColorPalette,

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
	.color_palette = ColorPalette.fromHex(
		.{
			0xffff00,
			0x00ff00,
			0x00ffff,
			0x0000ff,
			0xff00ff,
			0xff0000,
		}
	)
};

pub const ColorPalette = struct {
	colors: [sizes_amount]rl.Color = @splat(rl.Color.white),

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
