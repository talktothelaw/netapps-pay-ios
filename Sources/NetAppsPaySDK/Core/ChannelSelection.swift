// ============================================================
// PAYMENT CHANNEL SELECTION (pure, testable)
// ============================================================
//
// Mirrors the web SDK's `channelSelection.ts` so the behaviour is identical
// across platforms:
//
//   • The backend channel list (with `isActive`) is the source of truth.
//   • A channel is "available" only when it is active.
//   • The pre-selected channel is the merchant's configured default IF it is
//     active, otherwise the FIRST active channel.
//   • Card is never hard-coded as the default — it is selected only when it is
//     the configured default (and active) or genuinely the first active channel.
//   • When no channel is active, `resolveDefault` returns nil so the UI can show
//     an "unavailable" state instead of a blank screen.
// ============================================================

import Foundation

extension PaymentChannel {

    /// Compute the channels that should be offered to the customer, in priority order.
    ///
    /// Precedence:
    ///   1. If `apiChannels` is non-empty, only its ACTIVE channels are eligible
    ///      (the backend is authoritative once it has responded). When the merchant
    ///      restricted `configChannels`, the result is the intersection, preserving
    ///      the merchant's order. The result may legitimately be empty → "no active
    ///      channels".
    ///   2. If the backend has not returned channels yet, fall back to the merchant's
    ///      configured channels, then to every channel.
    ///
    /// Channels are returned de-duplicated and in backend/merchant order (NOT
    /// card-first). De-duplication applies to every branch: several backend rows
    /// can map to the same channel (e.g. `moni_flow` + `marketplace`), and a
    /// merchant may repeat a channel in `configChannels` — either one would
    /// otherwise render the same tab N times.
    static func availableChannels(
        apiChannels: [APIPaymentChannel],
        configChannels: [PaymentChannel]?
    ) -> [PaymentChannel] {
        if !apiChannels.isEmpty {
            var seen = Set<PaymentChannel>()
            var active: [PaymentChannel] = []
            for channel in apiChannels {
                guard channel.isActive == true,
                      let mapped = PaymentChannel.fromAPICode(channel.code ?? "") else { continue }
                if seen.insert(mapped).inserted {
                    active.append(mapped)
                }
            }

            // Backend has spoken: respect it fully, even when the result is empty.
            if let configChannels = configChannels, !configChannels.isEmpty {
                return deduped(configChannels.filter { seen.contains($0) })
            }
            return active
        }

        // Backend channels not available yet — use merchant config, then all channels.
        if let configChannels = configChannels, !configChannels.isEmpty {
            return deduped(configChannels)
        }
        return PaymentChannel.allCases
    }

    private static func deduped(_ channels: [PaymentChannel]) -> [PaymentChannel] {
        var seen = Set<PaymentChannel>()
        return channels.filter { seen.insert($0).inserted }
    }

    /// Resolve which channel should be pre-selected when the widget loads.
    ///
    ///   • Returns `preferred` (the merchant's configured default) when it is one
    ///     of `available`.
    ///   • Otherwise returns the first available active channel.
    ///   • Returns nil when there are no available channels, signalling the caller
    ///     to render an "unavailable" state instead of a blank screen.
    static func resolveDefault(
        available: [PaymentChannel],
        preferred: PaymentChannel?
    ) -> PaymentChannel? {
        guard !available.isEmpty else { return nil }
        if let preferred = preferred, available.contains(preferred) {
            return preferred
        }
        return available.first
    }
}
