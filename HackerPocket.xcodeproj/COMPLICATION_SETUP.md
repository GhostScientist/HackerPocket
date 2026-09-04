# Hacker Pocket Complication Setup

## Overview
This complication allows users to quickly access Hacker News stories from their Apple Watch face.

## Files Created/Modified
1. **HackerPocketWidget.swift** - The main widget/complication implementation (updated to use App Intents)
2. **OpenAppIntent.swift** - App Intent that opens the main app when non-rectangular complications are tapped
3. **HackerPocket-Watch-App-Info.plist** - Registers the `hackerpocket` deep-link scheme

## Setup Instructions

### 1. Add Files to Correct Targets
Make sure the files are added to the right targets:

**OpenAppIntent.swift** must be added to:
- ✅ Watch App target
- ✅ Widget Extension target

**HackerPocketWidget.swift** should be in:
- ✅ Widget Extension target only

### 2. Build and Run
1. Build and run the app on your Apple Watch or simulator
2. Long press on your watch face to edit
3. Tap on a complication slot
4. Scroll to find "Hacker News"
5. Select it and tap the complication to test - it will open your app!

## How It Works
- **App Intent with `openAppWhenRun`**: The `OpenAppIntent` has `openAppWhenRun = true`, which tells watchOS to automatically launch the app when the intent is triggered
- **Button with Intent**: Circular, corner, and inline complications use `Button(intent: OpenAppIntent())` to open the app
- **Rectangular deep link**: The rectangular complication uses `widgetURL` with the fetched story ID; the watch app routes `hackerpocket://story/{id}` to that story's detail screen

## Supported Complication Families
- **Circular** - Shows HN logo and text
- **Rectangular** - Shows icon, title, and top story
- **Corner** - Shows "HN" with icon
- **Inline** - Shows icon and "Hacker News" text

## Customization
You can customize:
- **Update frequency** - Change the timeline policy in `getTimeline()`
- **Design** - Modify the views for each widget family
- **Data** - Fetch more story data to display in complications
- **Colors** - Adjust tints and styles to match your branding

## Troubleshooting
- **Widget not appearing**: Ensure the Widget Extension target is properly configured
- **App not opening**: Make sure `OpenAppIntent.swift` is added to BOTH the Watch App target and Widget Extension target
- **Rectangular complication opens the root**: Confirm the watch app's URL scheme and `.onOpenURL` route are present
- **Build errors**: Ensure you've imported `AppIntents` framework in both files
- **Data not loading**: Check network permissions for the Widget Extension
