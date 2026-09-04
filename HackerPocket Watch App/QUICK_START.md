# Quick Start: Testing Your Complication

## What Changed
✅ **Removed** `handlesExternalEvents(matching:)` from HackerPocketApp.swift (not available on watchOS)  
✅ **Created** `OpenAppIntent.swift` - App Intent that opens your app  
✅ **Updated** `HackerPocketWidget.swift` - Uses App Intents for root launches and a story URL for rectangular deep links
✅ **Wired** the `hackerpocket` URL scheme through `ContentView.onOpenURL`

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
6. The rectangular complication should open the story it displays; other families open the main ContentView.

## How It Works
- `OpenAppIntent` has `openAppWhenRun = true` which automatically launches the app
- Circular, corner, and inline views use `Button(intent: OpenAppIntent())` to trigger the launch
- The rectangular view uses `widgetURL` with `hackerpocket://story/{id}`, which `ContentView.onOpenURL` routes to `DetailView`
