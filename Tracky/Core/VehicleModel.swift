import Foundation

/// A very simple longitudinal vehicle model, shared by the Simulator drive
/// source and the demo-data generator so simulated runs behave the same
/// everywhere.
///
/// Acceleration falls off exponentially with speed, which is what a real car
/// does once aerodynamic drag and gearing start to bite, and is clipped by a
/// traction limit plus a short ramp so the launch is not instantaneous.
struct VehicleModel: Equatable {
    /// Acceleration available at a standstill, m/s².
    var launchAcceleration: Double = 7.1
    /// Speed constant of the exponential fall-off, m/s.
    var speedConstant: Double = 40
    /// Most the tyres will take, m/s².
    var tractionLimit: Double = 8.4
    /// Braking deceleration, m/s².
    var brakingDeceleration: Double = 9.2
    /// Seconds for the launch to reach full acceleration.
    var launchRamp: Double = 0.3

    static let `default` = VehicleModel()

    /// A quicker car, used to give the demo data some spread.
    static func scaled(byFactor factor: Double) -> VehicleModel {
        var model = VehicleModel()
        model.launchAcceleration *= factor
        model.tractionLimit *= factor
        return model
    }

    func acceleration(atSpeed speed: Double, secondsSinceLaunch: Double) -> Double {
        let available = launchAcceleration * exp(-speed / speedConstant)
        let ramp = launchRamp > 0 ? min(1, secondsSinceLaunch / launchRamp) : 1
        return min(available, tractionLimit) * ramp
    }
}
