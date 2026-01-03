AppIcon Setup Instructions:
===========================

1. Save your Achieva logo image as a 1024x1024 PNG file
   - Name it: AppIcon.png (or any name)
   - Must be exactly 1024x1024 pixels
   - No transparency (solid background)
   - No rounded corners (Xcode will add them)

2. Copy the image file into this AppIcon.appiconset folder

3. Update Contents.json to reference your image file:
   - The "filename" field should match your image filename

OR

Use Xcode (easier):
1. Open Achieva.xcodeproj in Xcode
2. Right-click on Assets.xcassets in Project Navigator
3. Select "New iOS App Icon" if it doesn't show AppIcon
4. Drag your 1024x1024 image into the App Store slot
