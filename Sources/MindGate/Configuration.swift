import Foundation
import SwiftUI

struct Configuration {
    // MARK: - Distracting Applications
    static let distractingApps = [
        "Discord",
        "Slack",
        "Twitter",
        "Telegram",
        "Reddit",
        "TikTok",
        "Instagram",
        "Facebook",
        "Netflix",
        "YouTube",
        "Twitch"
    ]
    
    // MARK: - Restricted Website Keywords
    static let restrictedKeywords = [
        "youtube",
        "twitter",
        "x.com",
        "facebook",
        "instagram",
        "tiktok",
        "reddit",
        "twitch",
        "netflix",
        "spotify",
        "discord",
        "linkedin",
        "pinterest",
        "snapchat",
        "whatsapp",
        "telegram",
        "medium",
        "buzzfeed",
        "hackernews",
        "producthunt",
        "dribbble",
        "behance",
        "imgur",
        "giphy",
        "9gag",
        "memes",
        "gaming",
        "espn",
        "bleacher",
        "cnn",
        "fox news",
        "msnbc",
        "bbc",
        "news",
        "weather",
        "stocks",
        "crypto",
        "bitcoin",
        "trading",
        "shopping",
        "amazon",
        "ebay",
        "etsy",
        "walmart",
        "target",
        "fashion",
        "celebrity",
        "gossip",
        "entertainment",
        "movies",
        "tv shows",
        "streaming",
        "video",
        "viral",
        "trending"
    ]
    
    // MARK: - Browsers to Monitor
    static let monitoredBrowsers = [
        "Safari",
        "Google Chrome",
        "Microsoft Edge",
        "Firefox",
        "Brave"
    ]
    
    // MARK: - Ollama Configuration
    static let ollamaURL = "http://localhost:11434/api/generate"
    static let ollamaModel = "lfm2.5-thinking:1.2b"
    
    // MARK: - Access Durations (in seconds)
    static let accessDurations: [TimeInterval] = [
        300,  // 5 minutes
        600,  // 10 minutes
        900   // 15 minutes
    ]
    
    static let accessDurationLabels = ["5 Mins", "10 Mins", "15 Mins"]
    
    // MARK: - UI Styling
    struct Colors {
        static let primary = Color.white
        static let secondary = Color.white.opacity(0.8)
        static let accent = Color.white.opacity(0.6)
        static let background = Color.black
        static let surface = Color.black
        static let text = Color.white
        static let textSecondary = Color.white.opacity(0.7)
    }
    
    struct Animation {
        static let orbBreathingDuration: Double = 2.0
        static let orbTransitionDuration: Double = 0.3
        static let overlayFadeDuration: Double = 0.5
    }
    
    struct Dimensions {
        static let orbSize: CGFloat = 60
        static let orbExpandedWidth: CGFloat = 380
        static let orbExpandedHeight: CGFloat = 380
        static let chatCornerRadius: CGFloat = 180
    }
}
