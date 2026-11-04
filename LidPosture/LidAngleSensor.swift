import Foundation
import IOKit.hid

/// Reads the MacBook lid (hinge) angle from the undocumented HID sensor hub.
/// Apple VID 0x05AC, sensor hub PID 0x8104, usage page 0x0020 (Sensor).
/// Based on community reverse engineering (LidAngleSensor, pybooklid, lid-angle).
/// Not every MacBook exposes it — `init` returns nil when the sensor is absent.
final class LidAngleSensor {
    private let manager: IOHIDManager
    private let device: IOHIDDevice

    init?() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
            kIOHIDPrimaryUsagePageKey: 0x0020,
            // Usage 0x8A is what open-source readers match on. If the sensor is not
            // found on your Mac, try removing this line first.
            kIOHIDPrimaryUsageKey: 0x008A,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = devices.first,
              IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess
        else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return nil
        }
        self.manager = manager
        self.device = device
    }

    /// Current angle in degrees (0 = closed, ~180 = flat), or nil on read failure.
    func read() -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        // Angle is a little-endian UInt16 in bytes 1–2 of feature report 1.
        let raw = UInt16(report[2]) << 8 | UInt16(report[1])
        return Double(raw)
    }

    deinit {
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
}
