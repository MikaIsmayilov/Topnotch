import SwiftUI

/// Hero conditions with an inline unit switch, an hourly strip, and the supporting
/// numbers — composed as modules to match the rest of the panel.
struct WeatherWidget: View {
    @ObservedObject var service: WeatherService
    @ObservedObject var settings: SettingsStore

    var body: some View {
        if let snapshot = service.snapshot {
            VStack(spacing: 10) {
                heroCard(snapshot)
                    .frame(height: 124)
                hourlyCard()
                    .frame(height: 72)
                statsRow(snapshot)
                    .frame(maxHeight: .infinity)
            }
        } else if service.permissionDenied {
            EmptyStateView(
                symbol: "location.slash",
                title: "Location access is off",
                subtitle: "Enable it in System Settings → Privacy & Security"
            )
        } else {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Getting weather…")
                    .font(.ui(12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Hero

    private func heroCard(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 16) {
            Image(systemName: snapshot.symbol)
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)
                .frame(width: 58)

            VStack(alignment: .leading, spacing: 1) {
                Text(temperature(snapshot.temperatureC))
                    .font(.numeric(40, .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(snapshot.condition)
                    .font(.ui(12.5))
                    .foregroundStyle(Theme.textSecondary)
                if let place = service.placeName {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill").font(.ui(8))
                        Text(place).font(.ui(10))
                    }
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                unitPicker
                Spacer(minLength: 0)
                Button { service.refresh() } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise").font(.ui(9, .semibold))
                        Text(Self.updatedFormatter.string(from: snapshot.fetchedAt)).font(.ui(9.5))
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .cardSurface()
    }

    private var unitPicker: some View {
        HStack(spacing: 2) {
            ForEach(TemperatureUnit.allCases) { unit in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        settings.temperatureUnit = unit
                    }
                } label: {
                    Text(unit.label)
                        .font(.ui(10.5, .semibold))
                        .foregroundStyle(settings.temperatureUnit == unit ? .black : Theme.textSecondary)
                        .frame(width: 28, height: 20)
                        .background(
                            Capsule().fill(settings.temperatureUnit == unit ? Color.white.opacity(0.92) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.surfaceRaised))
    }

    // MARK: - Hourly

    private func hourlyCard() -> some View {
        Group {
            if service.hourly.isEmpty {
                Text("Hourly forecast unavailable")
                    .font(.ui(10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(service.hourly.enumerated()), id: \.element.id) { index, hour in
                            VStack(spacing: 4) {
                                Text(index == 0 ? "Now" : Self.hourFormatter.string(from: hour.date))
                                    .font(.ui(9.5, .medium))
                                    .foregroundStyle(Theme.textTertiary)
                                Image(systemName: hour.symbol)
                                    .font(.ui(13))
                                    .symbolRenderingMode(.multicolor)
                                Text(temperature(hour.temperatureC))
                                    .font(.numeric(11, .medium))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .frame(width: 46)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.vertical, 8)
        .cardSurface()
    }

    // MARK: - Stats

    private func statsRow(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 10) {
            StatTile(symbol: "thermometer.medium", label: "Feels like", value: temperature(snapshot.apparentTemperatureC))
            StatTile(symbol: "humidity.fill", label: "Humidity", value: "\(snapshot.humidity)%")
            StatTile(symbol: "wind", label: "Wind", value: wind(snapshot.windKph))
        }
    }

    // MARK: - Formatting

    private func temperature(_ celsius: Double) -> String {
        switch settings.temperatureUnit {
        case .celsius: return "\(Int(celsius.rounded()))°"
        case .fahrenheit: return "\(Int((celsius * 9 / 5 + 32).rounded()))°"
        }
    }

    private func wind(_ kph: Double) -> String {
        switch settings.temperatureUnit {
        case .celsius: return "\(Int(kph.rounded())) km/h"
        case .fahrenheit: return "\(Int((kph * 0.621371).rounded())) mph"
        }
    }

    private static let updatedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("j")
        return f
    }()
}

private struct StatTile: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.ui(9))
                Text(label.uppercased())
                    .font(.ui(8.5, .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.numeric(16, .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .cardSurface()
    }
}

extension View {
    /// The standard module surface used across the panel.
    func cardSurface(cornerRadius: CGFloat = 16) -> some View {
        self
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Theme.hairline, lineWidth: 1)
            )
    }
}
