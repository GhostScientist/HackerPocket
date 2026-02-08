# Quick Start: Testing Your Complication

## What Changed
✅ **Removed** `handlesExternalEvents(matching:)` from HackerPocketApp.swift (not available on watchOS)  
✅ **Created** `OpenAppIntent.swift` - App Intent that opens your app  
✅ **Updated** `HackerPocketWidget.swift` - Now uses App Intents instead of URL schemes  
✅ **Removed** need for URL scheme configuration in Info.plist

## Critical Step: Target Membership
**You MUST add `OpenAppIntent.swift` to BOTH targets:**

1. In Xcode, select `OpenAppIntent.swift` in the Project Navigator
2. Open the File Inspector (⌥⌘1)
3. Under "Target Membership", check BOTH:
   - ✅ HackerPocket Watch App
   - ✅ HackerPocketWidget (or your widget extension name)

## Testing
1. Build and run on Apple Watch or Simulator
2. Long press your watch face → Edit
3. Tap a complication slot
4. Find and select "Hacker News"
5. Exit edit mode and tap the complication
6. Your app should open to the main ContentView! 🎉

## How It Works
- `OpenAppIntent` has `openAppWhenRun = true` which automatically launches the app
- Each widget view uses `Button(intent: OpenAppIntent())` to trigger the launch
- No URL schemes or special handling needed - watchOS does it all automatically!
