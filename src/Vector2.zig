const std = @import("std");

pub const Vector2 = @This();

data: @Vector(2, f32),

// Component access

pub inline fn x(a: Vector2) f32 {
	return a.data[0];
}

pub inline fn y(a: Vector2) f32 {
	return a.data[1];
}

// Mutable component access

pub inline fn xRef(a: *Vector2) *f32 {
	return &a.data[0];
}

pub inline fn yRef(a: *Vector2) *f32 {
	return &a.data[1];
}

// Construction

pub inline fn init(x_: f32, y_: f32) Vector2 {
	return .{ .data = .{ x_, y_ } };
}

/// Returns a vector where both components are `value`.
pub inline fn splat(value: f32) Vector2 {
	return .{ .data = @splat(value) };
}

/// Returns the zero vector.
pub inline fn zero() Vector2 {
	return splat(0.0);
}

// Component-wise arithmetic

/// Component-wise addition.
pub inline fn add(a: Vector2, b: Vector2) Vector2 {
	return .{ .data = a.data + b.data };
}

/// Component-wise subtraction.
pub inline fn sub(a: Vector2, b: Vector2) Vector2 {
	return .{ .data = a.data - b.data };
}

/// Component-wise multiplication (Hadamard product).
pub inline fn mul(a: Vector2, b: Vector2) Vector2 {
	return .{ .data = a.data * b.data };
}

/// Component-wise division.
pub inline fn div(a: Vector2, b: Vector2) Vector2 {
	return .{ .data = a.data / b.data };
}

/// Negates a vector.
pub inline fn neg(a: Vector2) Vector2 {
	return .{ .data = -a.data };
}

/// Scales a vector by a scalar.
pub inline fn scale(a: Vector2, scalar: f32) Vector2 {
	return .{ .data = a.data * @as(@Vector(2, f32), @splat(scalar)) };
}

// Products & magnitude

/// Dot product.
pub inline fn dot(a: Vector2, b: Vector2) f32 {
	return @reduce(.Add, a.data * b.data);
}

/// 2D cross product (returns the scalar z-component of the 3D cross).
pub inline fn cross(a: Vector2, b: Vector2) f32 {
	return (a.data[0] * b.data[1]) - (a.data[1] * b.data[0]);
}

/// Squared length. Prefer over `length` when only comparing magnitudes.
pub inline fn lengthSquared(a: Vector2) f32 {
	return dot(a, a);
}

/// Modulus/magnitude of the vector
pub inline fn length(a: Vector2) f32 {
	return @sqrt(lengthSquared(a));
}

/// Euclidean distance between two points.
pub inline fn distance(a: Vector2, b: Vector2) f32 {
	return length(sub(a, b));
}

// Interpolation & transformation

/// Returns a unit vector in the same direction.
/// Returns a zero vector if the input has zero length.
pub inline fn normalized(a: Vector2) Vector2 {
	const len_sq = lengthSquared(a);
	if (len_sq == 0.0) return zero();
	return scale(a, 1.0 / @sqrt(len_sq));
}

/// Linearly interpolates between `a` and `b` by factor `t` (clamped to [0, 1]).
pub inline fn lerp(a: Vector2, b: Vector2, t: f32) Vector2 {
	const clamped_t = @max(0.0, @min(1.0, t));
	return add(a, scale(sub(b, a), clamped_t));
}

/// Reflects vector `v` about a surface with normal `n`.
pub inline fn reflect(v: Vector2, n: Vector2) Vector2 {
	// v - 2 * dot(v, n) * n
	return sub(v, scale(n, 2.0 * dot(v, n)));
}

/// Clamps each component between the corresponding components of `min` and `max`.
pub inline fn clamp(a: Vector2, min: Vector2, max: Vector2) Vector2 {
	return .{ .data = @min(@max(a.data, min.data), max.data) };
}

/// Angle (in radians) between two vectors.
pub inline fn angleBetween(a: Vector2, b: Vector2) f32 {
	const cos_theta = dot(a, b) / (length(a) * length(b));
	return std.math.acos(@max(-1.0, @min(1.0, cos_theta)));
}

// Others

pub fn format(self: Vector2, writer: *std.Io.Writer) !void {
	try writer.print("[{}, {}]", .{self.x(), self.y()});
}
