import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Turns a run into something shareable: a summary image, or CSV for anyone who
/// wants to do their own maths.
///
/// Nothing is uploaded. Files are written to the temporary directory and handed
/// to the system share sheet, so the user decides where they go.
@MainActor
enum ExportService {

    // MARK: - CSV

    /// Full telemetry, one row per recorded sample.
    ///
    /// Coordinates are only included when the run still stores its route, so
    /// exporting cannot leak location data the user asked to remove.
    static func telemetryCSV(for run: Run, speedUnit: SpeedUnit, distanceUnit: DistanceUnit) -> String {
        var lines: [String] = []

        lines.append("# Tracky telemetry export")
        lines.append("# mode,\(escape(run.modeTitle))")
        lines.append("# date,\(Format.isoTimestamp.string(from: run.date))")
        lines.append("# result_seconds,\(String(format: "%.3f", run.duration))")
        lines.append("# vehicle,\(escape(run.vehicle?.name ?? ""))")
        lines.append("# gps_quality,\(run.quality.rawValue)")
        lines.append("# average_accuracy_m,\(String(format: "%.2f", run.averageAccuracy))")
        lines.append("# elevation_source,\(run.elevationSource.rawValue)")
        lines.append("# includes_location,\(run.storesRoute)")

        var header = [
            "time_s",
            "speed_mps",
            "speed_\(speedUnit.rawValue)",
            "distance_m",
            "distance_\(distanceUnit.shortSymbol)",
            "altitude_m",
            "longitudinal_g",
            "lateral_g",
            "vertical_g",
            "horizontal_accuracy_m"
        ]
        if run.storesRoute {
            header.append("latitude")
            header.append("longitude")
        }
        lines.append(header.joined(separator: ","))

        for point in run.telemetry {
            var row = [
                String(format: "%.3f", point.t),
                String(format: "%.3f", point.speed),
                String(format: "%.2f", speedUnit.value(fromMetersPerSecond: point.speed)),
                String(format: "%.2f", point.distance),
                String(format: "%.2f", distanceUnit.shortValue(fromMeters: point.distance)),
                String(format: "%.2f", point.altitude),
                String(format: "%.4f", point.longitudinalG),
                String(format: "%.4f", point.lateralG),
                String(format: "%.4f", point.verticalG),
                String(format: "%.2f", point.horizontalAccuracy)
            ]
            if run.storesRoute {
                row.append(String(format: "%.7f", point.latitude))
                row.append(String(format: "%.7f", point.longitude))
            }
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    /// One row per run, for a spreadsheet of everything recorded.
    static func summaryCSV(for runs: [Run], speedUnit: SpeedUnit, distanceUnit: DistanceUnit) -> String {
        var lines: [String] = []
        lines.append([
            "date",
            "mode",
            "result_seconds",
            "vehicle",
            "start_speed_\(speedUnit.rawValue)",
            "end_speed_\(speedUnit.rawValue)",
            "max_speed_\(speedUnit.rawValue)",
            "distance_m",
            "max_accel_g",
            "max_braking_g",
            "max_lateral_g",
            "elevation_change_m",
            "gps_quality",
            "average_accuracy_m",
            "fix_rate_hz",
            "valid"
        ].joined(separator: ","))

        for run in runs.sorted(by: .date) {
            lines.append([
                Format.isoTimestamp.string(from: run.date),
                escape(run.modeTitle),
                String(format: "%.3f", run.duration),
                escape(run.vehicle?.name ?? ""),
                String(format: "%.2f", speedUnit.value(fromMetersPerSecond: run.startSpeed)),
                String(format: "%.2f", speedUnit.value(fromMetersPerSecond: run.endSpeed)),
                String(format: "%.2f", speedUnit.value(fromMetersPerSecond: run.maxSpeed)),
                String(format: "%.2f", run.distance),
                String(format: "%.3f", run.maxAccelerationG),
                String(format: "%.3f", run.maxBrakingG),
                String(format: "%.3f", run.maxLateralG),
                String(format: "%.2f", run.elevationChange),
                run.quality.rawValue,
                String(format: "%.2f", run.averageAccuracy),
                String(format: "%.2f", run.sampleRate),
                run.isValid ? "yes" : "no"
            ].joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    /// Writes text to a uniquely named file in the temporary directory and
    /// returns its URL, or nil if it could not be written.
    static func writeTemporaryFile(named name: String, contents: String) -> URL? {
        let safeName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func telemetryFile(for run: Run, speedUnit: SpeedUnit, distanceUnit: DistanceUnit) -> URL? {
        let stamp = fileStamp(for: run.date)
        let name = "Tracky-\(run.modeTitle.replacingOccurrences(of: " ", with: ""))-\(stamp).csv"
        return writeTemporaryFile(
            named: name,
            contents: telemetryCSV(for: run, speedUnit: speedUnit, distanceUnit: distanceUnit)
        )
    }

    static func summaryFile(for runs: [Run], speedUnit: SpeedUnit, distanceUnit: DistanceUnit) -> URL? {
        writeTemporaryFile(
            named: "Tracky-runs-\(fileStamp(for: Date())).csv",
            contents: summaryCSV(for: runs, speedUnit: speedUnit, distanceUnit: distanceUnit)
        )
    }

    // MARK: - Share card

    #if canImport(UIKit)
    /// Renders the summary card at 3x so it looks right when posted.
    static func shareCardImage(
        for run: Run,
        speedUnit: SpeedUnit,
        distanceUnit: DistanceUnit
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: ShareCardView(run: run, speedUnit: speedUnit, distanceUnit: distanceUnit)
        )
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// The card as a SwiftUI `Image`, which is what `ShareLink` wants.
    static func shareCard(
        for run: Run,
        speedUnit: SpeedUnit,
        distanceUnit: DistanceUnit
    ) -> Image? {
        shareCardImage(for: run, speedUnit: speedUnit, distanceUnit: distanceUnit).map(Image.init(uiImage:))
    }
    #endif

    // MARK: - Helpers

    /// Wraps a field in quotes when it contains anything that would break a CSV.
    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func fileStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }
}
