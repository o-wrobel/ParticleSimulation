const std = @import("std");
const rl = @import("raylib");
const Vector2 = @import("Vector2.zig");
const deltaTime = rl.getFrameTime;

var particle_size: i8 = 1;
const minimum_size = 10;
const size_factor = 10;

inline fn toRaylibVector(vector: Vector2) rl.Vector2 {
	return .init(vector.x(), vector.y());
}

inline fn toVector2(vector: rl.Vector2) Vector2 {
	return Vector2.init(vector.x, vector.y);
}

const ParticleConfig = struct {
	initial_count: usize,
	size_factor: f32,
	minimum_size: f32,
};

const PhysicsConfig = struct {
	gravity: f32 = 1000,
	wall_restitution: f32 = 0.99,
	velocity_damping: f32 = 0.9999,
};

const ZonConfig = struct {
	physics: PhysicsConfig,
	particles: ParticleConfig
};

const Color = enum (i8) {
	red = 1,
	blue = 2,
	green = 3,
	yellow = 4,
	purple = 5,
	orange = 6,
	lime = 7,

	pub fn getColor(self: Color) rl.Color {
		return switch (self) {
			.red => rl.Color.red,
			.blue => rl.Color.blue,
			.green => rl.Color.green,
			.yellow => rl.Color.yellow,
			.purple => rl.Color.violet,
			.orange => rl.Color.orange,
			.lime => rl.Color.lime,
		};
	}
};

const Particle = struct {
	radius: f32,
	pos: Vector2 = .zero(),
	velocity: Vector2 = .zero(),

	color: rl.Color,
	collided: bool = false,

	health: i32 = 100,

	pub fn side(self: Particle, option: enum {right, top, left, bottom}) f32 {
		return switch (option) {
			.right => self.pos.x() + self.radius,
			.top => self.pos.y() - self.radius,
			.left => self.pos.x() - self.radius,
			.bottom => self.pos.y() + self.radius,
		};
	}
};

const ParticleSet = struct {
	list: std.ArrayList(Particle),

	pub fn init(count: usize, random: std.Random, allocator: std.mem.Allocator) !ParticleSet {
		// const buffer = try allocator.alloc(Particle, count);

		var list: std.ArrayList(Particle) = try .initCapacity(allocator, count);
		for (0..count) |_| {
			const size = random.intRangeAtMost(i8, 1, 6);
			var particle = getFancyParticle(size);
			particle.pos = .init(
				@floatFromInt(random.intRangeAtMost(i32, 100, 700)),
				@floatFromInt(random.intRangeAtMost(i32, 100, 500)),
			);
			particle.velocity = .init(
				@floatFromInt(random.intRangeAtMost(i32, -100, 100)),
				0
			);
			list.appendAssumeCapacity(particle);
		}
		return .{
			.list = list,
		};
	}

	pub fn deinit(self: *ParticleSet, allocator: std.mem.Allocator) void {
		self.list.deinit(allocator);
	}

	pub fn update(self: *ParticleSet, box: rl.Rectangle, physics_data: PhysicsConfig) void {
		const particles = self.list.items;
		const gravity = physics_data.gravity;
		const velocity_damping = physics_data.velocity_damping;
		const wall_restitution = physics_data.wall_restitution;

		// Apply velocity and handle collisions with box
		for (particles) |*p| {
			p.collided = false;
			p.pos = p.pos.add(p.velocity.scale(deltaTime()));
			p.velocity.yRef().* += gravity * deltaTime();

			p.velocity = p.velocity.scale(velocity_damping);

			if (p.side(.left) < box.x) {
				p.velocity.xRef().* = -p.velocity.x() * wall_restitution;
				p.pos.xRef().* = box.x + p.radius;
			} else if (p.side(.right) > box.x + box.width) {
				p.velocity.xRef().* = -p.velocity.x() * wall_restitution;
				p.pos.xRef().* = box.x + box.width - p.radius;
			}

			if (p.side(.top) < box.y) {
				p.velocity.yRef().* = -p.velocity.y() * wall_restitution;
				p.pos.yRef().* = box.y + p.radius;
			} else if (p.side(.bottom) > box.y + box.height) {
				p.velocity.yRef().* = -p.velocity.y() * wall_restitution;
				p.pos.yRef().* = box.y + box.height - p.radius;
			}
		}

		// Particle-particle collision
		for (particles, 0..) |*a, i| {
			for (particles[i + 1 ..]) |*b| {
				const delta = Vector2.sub(a.pos, b.pos);
				const dist = delta.length();
				const overlap = a.radius + b.radius - dist;

				if (overlap > 0) {
					a.collided = true;
					b.collided = true;
					a.health -= 1;
					b.health -= 1;
					const m1 = a.radius * a.radius;
					const m2 = b.radius * b.radius;

					const v1 = a.velocity;
					const v2 = b.velocity;

					// Guard against particles exactly on top of each other
					const normal = if (dist > 0) delta.normalized()
						else Vector2.init(1, 0);
					const tangent: Vector2 = .init(normal.y(), -normal.x());

					const norm1 = Vector2.dot(normal, v1);
					const norm2 = Vector2.dot(normal, v2);

					const new_norm1 = (norm1 * (m1 - m2) + 2 * m2 * norm2) / (m1 + m2);
					const new_norm2 = (norm2 * (m2 - m1) + 2 * m1 * norm1) / (m2 + m1);

					const tan1 = Vector2.dot(tangent, v1);
					const tan2 = Vector2.dot(tangent, v2);

					const new_v1 = Vector2.add(
					    normal.scale(new_norm1),
					    tangent.scale(tan1)
					);
					const new_v2 = Vector2.add(
					    normal.scale(new_norm2),
					    tangent.scale(tan2)
					);

					a.velocity = new_v1;
					b.velocity = new_v2;

					// Nudge particles apart proportionally to inverse mass
					const inv_m1 = 1 / m1;
					const inv_m2 = 1 / m2;
					const total_inv = inv_m1 + inv_m2;
					a.pos = a.pos.add(normal.scale(overlap * inv_m1 / total_inv));
					b.pos = b.pos.sub(normal.scale(overlap * inv_m2 / total_inv));
				}
			}
		}
	}

	pub fn addParticle(self: *ParticleSet, particle: Particle, allocator: std.mem.Allocator) !void {
		try self.list.append(allocator, particle);
	}
};

fn getFancyParticle(size: i8) Particle {
	const color: Color = @enumFromInt(size);
	return Particle{
		.radius = minimum_size + size_factor * size,
		.color = color.getColor(),
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

/// Loads ZonData from a file in the current working directory
fn loadConfig(filename: []const u8, io: std.Io, allocator: std.mem.Allocator) !ZonConfig {
	const cwd = std.Io.Dir.cwd();
	const string = try std.Io.Dir.readFileAlloc(cwd, io, filename, allocator, .unlimited);
	defer allocator.free(string);

	const string_sentinel = try allocator.dupeSentinel(
		u8,
		string,
		0
	);

	defer allocator.free(string_sentinel);

	return try std.zon.parse.fromSlice(ZonConfig, allocator, string_sentinel, null, .{});
}

pub fn main(init: std.process.Init) !void {
	const allocator = init.gpa;
	const io = init.io;
	const random = (std.Random.IoSource{.io = io}).interface();

	// Engine Setup
	const config = try loadConfig("test.zig.zon", io, allocator);

	var particles: ParticleSet = try .init(config.particles.initial_count, random, allocator);
	defer particles.deinit(allocator);

	const box: rl.Rectangle = .init(40, 40, 800 - 80, 800 - 80);

	rl.initWindow(800, 800, "Physics simulation");
	defer rl.closeWindow();
	rl.setTargetFPS(60);

	while (!rl.windowShouldClose()) {
		// Update
		const mouse_pos = toVector2(rl.getMousePosition());

		const mouse_wheel = rl.getMouseWheelMove();
		particle_size += @trunc(mouse_wheel);
		particle_size = std.math.clamp(particle_size, 1, 6);

		var particle_to_be_placed = getFancyParticle(particle_size);
		particle_to_be_placed.pos = mouse_pos;

		if (rl.isMouseButtonPressed(.left)) {
			try particles.addParticle(particle_to_be_placed, allocator);
		}

		particles.update(box, config.physics);

		// Drawing
		rl.beginDrawing();
		rl.clearBackground(.ray_white);

		// drawRectangleLinesOutside(box, 10, .blue);
		rl.drawRectangleRec(box, .black);
		drawParticles(particles);
		drawParticlePreview(particle_to_be_placed);
		rl.drawFPS(40, 10);

		rl.endDrawing();
	}
}
