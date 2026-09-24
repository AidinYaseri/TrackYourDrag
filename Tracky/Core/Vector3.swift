import Foundation

/// Minimal 3-vector so the G-force maths can be unit tested without CoreMotion.
struct Vector3: Equatable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vector3(x: 0, y: 0, z: 0)

    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    var magnitude: Double { (x * x + y * y + z * z).squareRoot() }

    var normalized: Vector3 {
        let length = magnitude
        guard length > 1e-9 else { return .zero }
        return Vector3(x: x / length, y: y / length, z: z / length)
    }

    func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
}

/// Row-major 3x3 rotation matrix, matching CoreMotion's `CMRotationMatrix`
/// layout (m11...m33).
struct Matrix3: Equatable {
    var m11, m12, m13: Double
    var m21, m22, m23: Double
    var m31, m32, m33: Double

    static let identity = Matrix3(
        m11: 1, m12: 0, m13: 0,
        m21: 0, m22: 1, m23: 0,
        m31: 0, m32: 0, m33: 1
    )

    /// Rotates a vector expressed in the device frame into the attitude's
    /// reference frame.
    func rotate(_ vector: Vector3) -> Vector3 {
        Vector3(
            x: m11 * vector.x + m12 * vector.y + m13 * vector.z,
            y: m21 * vector.x + m22 * vector.y + m23 * vector.z,
            z: m31 * vector.x + m32 * vector.y + m33 * vector.z
        )
    }
}
