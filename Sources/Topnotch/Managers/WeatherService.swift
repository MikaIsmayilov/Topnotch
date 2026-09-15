import Foundation
import CoreLocation
import Combine

struct WeatherSnapshot {
    let temperatureC: Double
    let apparentTemperatureC: Double
    let humidity: Int
    let windKph: Double
    let condition: String
    let symbol: String
    let isDay: Bool
    let fetchedAt: Date
}

struct HourForecast: Identifiable, Equatable {
    let id: Int
    let date: Date
    let temperatureC: Double
    let symbol: String
}

/// Fetches current conditions and an hourly forecast from Open-Meteo (no API key
/// required) using the device's location, refreshing every 15 minutes. Falls back
/// silently if location is denied.
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var hourly: [HourForecast] = []
    @Published private(set) var placeName: String?
    @Published private(set) var permissionDenied = false

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastCoordinate: CLLocationCoordinate2D?
    private var refreshTimer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            permissionDenied = true
        default:
            locationManager.requestLocation()
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        if let lastCoordinate {
            fetchWeather(coordinate: lastCoordinate)
        } else {
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            permissionDenied = true
        case .notDetermined:
            break
        default:
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastCoordinate = location.coordinate
        fetchWeather(coordinate: location.coordinate)
        if placeName == nil {
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
                let name = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea
                DispatchQueue.main.async { self?.placeName = name }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient location errors just mean no weather until the next refresh.
    }

    private func fetchWeather(coordinate: CLLocationCoordinate2D) {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
        ]
        guard let url = components.url else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let response = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else { return }
            let current = response.current
            let isDay = current.is_day == 1
            let (label, symbol) = Self.describe(code: current.weather_code, isDay: isDay)
            let snapshot = WeatherSnapshot(
                temperatureC: current.temperature_2m,
                apparentTemperatureC: current.apparent_temperature,
                humidity: current.relative_humidity_2m,
                windKph: current.wind_speed_10m,
                condition: label,
                symbol: symbol,
                isDay: isDay,
                fetchedAt: Date()
            )

            let now = Date().addingTimeInterval(-1800)
            var hours: [HourForecast] = []
            if let h = response.hourly {
                for (index, stamp) in h.time.enumerated() where index < h.temperature_2m.count {
                    let date = Date(timeIntervalSince1970: TimeInterval(stamp))
                    guard date >= now else { continue }
                    let dayFlag = index < (h.is_day?.count ?? 0) ? (h.is_day?[index] == 1) : true
                    let (_, sym) = Self.describe(code: h.weather_code[index], isDay: dayFlag)
                    hours.append(HourForecast(id: stamp, date: date, temperatureC: h.temperature_2m[index], symbol: sym))
                    if hours.count == 12 { break }
                }
            }

            DispatchQueue.main.async {
                self?.snapshot = snapshot
                self?.hourly = hours
            }
        }.resume()
    }

    private static func describe(code: Int, isDay: Bool) -> (String, String) {
        switch code {
        case 0: return ("Clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2: return ("Partly Cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: return ("Overcast", "cloud.fill")
        case 45, 48: return ("Fog", "cloud.fog.fill")
        case 51, 53, 55, 56, 57: return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67, 80, 81, 82: return ("Rain", "cloud.rain.fill")
        case 71, 73, 75, 77, 85, 86: return ("Snow", "cloud.snow.fill")
        case 95, 96, 99: return ("Thunderstorms", "cloud.bolt.rain.fill")
        default: return ("Weather", "cloud.fill")
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let relative_humidity_2m: Int
        let wind_speed_10m: Double
        let weather_code: Int
        let is_day: Int
    }
    struct Hourly: Decodable {
        let time: [Int]
        let temperature_2m: [Double]
        let weather_code: [Int]
        let is_day: [Int]?
    }
    let current: Current
    let hourly: Hourly?
}
