//
//  Feed.swift
//  HackerPocket Watch App
//
//  The six story lists the HN Firebase API exposes.
//

import Foundation

/// Every feed is the same endpoint shape, so the only thing that varies is the
/// path. Ordering is HN's ranking in all six cases — never re-sort the IDs.
///
/// Only `topstories` returns 500 entries; the rest are much shorter (Jobs is
/// usually a couple of dozen), so nothing may assume a fixed count.
enum Feed: String, CaseIterable, Identifiable {
    case top
    case new
    case best
    case ask
    case show
    case jobs

    var id: String { rawValue }

    var path: String {
        switch self {
        case .top: return "topstories.json"
        case .new: return "newstories.json"
        case .best: return "beststories.json"
        case .ask: return "askstories.json"
        case .show: return "showstories.json"
        case .jobs: return "jobstories.json"
        }
    }

    var displayName: String {
        switch self {
        case .top: return "Top"
        case .new: return "New"
        case .best: return "Best"
        case .ask: return "Ask HN"
        case .show: return "Show HN"
        case .jobs: return "Jobs"
        }
    }

    var symbolName: String {
        switch self {
        case .top: return "flame"
        case .new: return "clock"
        case .best: return "star"
        case .ask: return "questionmark.bubble"
        case .show: return "eye"
        case .jobs: return "briefcase"
        }
    }
}
