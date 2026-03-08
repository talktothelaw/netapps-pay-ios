// ============================================================
// DEVICE FINGERPRINT - UUID v7 generator
// ============================================================

import Foundation

struct DeviceFingerprint {
    
    /// Generates a UUID v7 (time-ordered) for device fingerprinting.
    /// UUID v7 layout: 48 bits timestamp | 4 bits version (0111) | 12 bits rand_a | 2 bits variant (10) | 62 bits rand_b
    static func generate() -> String {
        // Milliseconds since Unix epoch
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        
        // Generate random bytes
        var randomBytes = [UInt8](repeating: 0, count: 10)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        var uuid = [UInt8](repeating: 0, count: 16)
        
        // Bytes 0-5: 48-bit timestamp (big-endian)
        uuid[0] = UInt8((timestamp >> 40) & 0xFF)
        uuid[1] = UInt8((timestamp >> 32) & 0xFF)
        uuid[2] = UInt8((timestamp >> 24) & 0xFF)
        uuid[3] = UInt8((timestamp >> 16) & 0xFF)
        uuid[4] = UInt8((timestamp >> 8) & 0xFF)
        uuid[5] = UInt8(timestamp & 0xFF)
        
        // Byte 6: version (0111) + 4 bits random
        uuid[6] = (0x70) | (randomBytes[0] & 0x0F)
        
        // Byte 7: random
        uuid[7] = randomBytes[1]
        
        // Byte 8: variant (10) + 6 bits random
        uuid[8] = (0x80) | (randomBytes[2] & 0x3F)
        
        // Bytes 9-15: random
        uuid[9] = randomBytes[3]
        uuid[10] = randomBytes[4]
        uuid[11] = randomBytes[5]
        uuid[12] = randomBytes[6]
        uuid[13] = randomBytes[7]
        uuid[14] = randomBytes[8]
        uuid[15] = randomBytes[9]
        
        // Format as UUID string
        let hex = uuid.map { String(format: "%02x", $0) }.joined()
        let idx = hex.index(hex.startIndex, offsetBy: 0)
        
        let p1 = String(hex[hex.index(idx, offsetBy: 0)..<hex.index(idx, offsetBy: 8)])
        let p2 = String(hex[hex.index(idx, offsetBy: 8)..<hex.index(idx, offsetBy: 12)])
        let p3 = String(hex[hex.index(idx, offsetBy: 12)..<hex.index(idx, offsetBy: 16)])
        let p4 = String(hex[hex.index(idx, offsetBy: 16)..<hex.index(idx, offsetBy: 20)])
        let p5 = String(hex[hex.index(idx, offsetBy: 20)..<hex.index(idx, offsetBy: 32)])
        
        return "\(p1)-\(p2)-\(p3)-\(p4)-\(p5)"
    }
}
