const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const Vector2 = @import("Vector2");

const deltaTime = rl.getFrameTime;

// stub
var particle_size: i8 = 1;
const minimum_size = 10;
const size_factor = 10;

pub const Physics = struct {
	gravity: f32 = 1000,
	wall_restitution: f32 = 0.99,
	velocity_damping: f32 = 0.9999,
};

// TODO: Add Box object

pub const Particle = struct {
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

pub const ParticleSet = struct {
	const log = std.log.scoped(.ParticleSet);
	list: std.ArrayList(Particle),

	pub fn init(count: usize, random: std.Random, allocator: std.mem.Allocator) !ParticleSet {
		// const buffer = try allocator.alloc(Particle, count);

		var list: std.ArrayList(Particle) = try .initCapacity(allocator, count);
		for (0..count) |_| {
			const size = random.intRangeAtMost(i8, 1, 6);
			var particle = Particle{
				.radius = minimum_size + size_factor * size,
				.color = .white,
			};
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

	pub fn update(self: *ParticleSet, box: rl.Rectangle, physics_data: Physics) void {
		const particles = self.list.items;
		const gravity = physics_data.gravity;
		const velocity_damping = physics_data.velocity_damping;
		const wall_restitution = physics_data.wall_restitution;

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
	}

	pub fn reset(self: *ParticleSet, allocator: std.mem.Allocator) !void {
		const initial_capacity = 10;
		self.list.deinit(allocator);
		self.list = try std.ArrayList(Particle).initCapacity(allocator, initial_capacity);
	}

	pub fn addParticle(self: *ParticleSet, particle: Particle, allocator: std.mem.Allocator) !void {
		log.debug("Added particle | pos: {f}, radius: {}", .{particle.pos, particle.radius});
		try self.list.append(allocator, particle);
	}
};
