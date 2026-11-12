import Foundation

/// Compile-time switches for unfinished features.
public enum FeatureFlags {
    /// Taiwan 大老二 interface (wording, 台灣常見 炒法 default, winner-takes-all scoring).
    ///
    /// On hold: Taiwan scoring is still to be decided by Kenny. While `false` the app always
    /// uses the Hong Kong interface, whatever the device language or saved setting, and
    /// Settings hides 地區介面. The TW code, strings and unit tests stay in the repo.
    /// UI tests can force it on with the `-enableTaiwan` launch argument.
    public static let taiwanEnabledByDefault = false
}

extension AppData {
    /// Interface region after applying 跟系統 and the Taiwan feature flag.
    public func interfaceRegion(systemRegion: InterfaceRegion, taiwanEnabled: Bool) -> InterfaceRegion {
        guard taiwanEnabled else { return .hongKong }
        return interfaceRegion(systemRegion: systemRegion)
    }
}
