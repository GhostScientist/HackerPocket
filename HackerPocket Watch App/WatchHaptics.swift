//
//  WatchHaptics.swift
//  HackerPocket Watch App
//

#if os(watchOS)
import WatchKit
#endif

enum WatchHaptics {
    static func success() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.success)
#endif
    }

    static func failure() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.failure)
#endif
    }

    static func upvote() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.directionUp)
#endif
    }
}
