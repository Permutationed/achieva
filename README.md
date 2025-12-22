# Bucketlist iOS App - Mock Frontend

A beautiful, modern iOS app for tracking and sharing bucket list goals with friends. Built with SwiftUI following clean design principles inspired by Instagram and Nike Run Club.

## Overview

This is a **fully functional mock frontend** with no backend integration. All data is loaded from JSON files and managed in-memory, perfect for prototyping and UI/UX testing.

## Features

### ✅ Home Feed
- Scrollable feed of posts from friends
- Like and comment functionality
- Beautiful post cards with evidence images
- Pull-to-refresh
- Detailed post view with goal information

### ✅ Friends Page
- Friend list with search functionality
- Pending friend requests with accept/decline
- Friend profile views with activity
- Clean card-based UI

### ✅ Goals Page
- Tabbed interface (Active, Completed, Collaborating)
- Create new goals with bucket lists
- Goal detail views with evidence
- Collaborative goal support
- Priority and status tracking

## Design System

### Color Palette
- **Primary**: #007AFF (Accent blue)
- **Success**: #34C759 (Green)
- **Like**: #FF3B30 (Red)
- **Warning**: #FF9500 (Orange)
- **Background**: #FFFFFF / #F7F7F7
- **Text**: #111111 / #6C6C6C

### Typography
- **SF Pro** font family (native iOS)
- Header 1: 34pt Semibold
- Header 2: 22pt Semibold
- Body Large: 17pt Regular
- Body Standard: 15pt Regular
- Caption: 13pt Medium

### Layout
- 8pt grid system
- 16pt screen edge padding
- 12pt card corner radius
- Generous white space

## Project Structure

```
mvp1/
├── BucketlistApp.swift          # App entry point
├── ContentView.swift             # Root TabView navigation
├── Models/
│   ├── User.swift
│   ├── Post.swift
│   ├── Goal.swift
│   ├── BucketList.swift
│   ├── Comment.swift
│   ├── Friendship.swift
│   └── MockDataLoader.swift      # JSON data loader
├── Theme/
│   ├── Colors.swift              # Color palette
│   └── Typography.swift          # Font styles
├── Views/
│   ├── Home/
│   │   ├── HomeFeedView.swift
│   │   └── PostDetailView.swift
│   ├── Friends/
│   │   ├── FriendsView.swift
│   │   └── FriendProfileView.swift
│   ├── Goals/
│   │   ├── GoalsView.swift
│   │   ├── CreateGoalView.swift
│   │   └── GoalDetailView.swift
│   └── Components/
│       ├── PostCard.swift
│       ├── FriendCard.swift
│       ├── GoalCard.swift
│       ├── PrimaryButton.swift
│       ├── LikeButton.swift
│       └── CommentRow.swift
└── MockData/
    ├── users.json                # 9 mock users
    ├── posts.json                # 10 mock posts
    ├── goals.json                # 8 mock goals
    ├── bucketlists.json          # 6 mock bucket lists
    └── friendships.json          # Mock friendships
```

## Getting Started

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- iOS 17.0+ target

### Installation

1. **Create a new Xcode project**:
   - Open Xcode
   - File → New → Project
   - Choose "App" under iOS
   - Product Name: `Bucketlist`
   - Interface: SwiftUI
   - Language: Swift

2. **Replace the default files** with the files from this directory

3. **Add JSON files to project**:
   - In Xcode, right-click on the project
   - Add Files to "Bucketlist"
   - Select all files in the `MockData/` folder
   - Make sure "Copy items if needed" is checked
   - Make sure "Add to targets: Bucketlist" is checked

4. **Organize files in Xcode**:
   - Create groups (folders) matching the structure above
   - Drag files into their respective groups

5. **Build and Run**:
   - Select a simulator (iPhone 15 Pro recommended)
   - Press Cmd+R or click the Play button

## Mock Data

The app includes realistic mock data:
- **9 users** with diverse profiles and activities
- **10 posts** with various goals and evidence
- **8 goals** across different bucket lists with different statuses
- **6 bucket lists** including collaborative ones
- **Friend relationships** with pending requests

Current user ID: `user_current`

## Key Components

### PostCard
Reusable card component for displaying posts in the feed with:
- User profile header
- Title and content
- Evidence image carousel
- Like/comment/share actions
- Collaborative badge

### GoalCard
Displays goal information with:
- Status indicator (colored badge)
- Target date
- Priority level
- Evidence thumbnails
- Parent bucket list name

### FriendCard
Friend list item with:
- Profile picture and bio
- Accept/decline buttons (for pending requests)
- Navigation to profile

### PrimaryButton
Standardized CTA button following design system

### LikeButton
Animated heart button with:
- Toggle animation
- Haptic feedback
- Like count display

## Interactive Features

### Working Features
- ✅ Tab navigation
- ✅ Post likes (in-memory)
- ✅ Pull-to-refresh
- ✅ Friend request accept/decline (in-memory)
- ✅ Search friends
- ✅ View post details
- ✅ View goal details
- ✅ Create goal form
- ✅ Goal status filtering

### Mock Features (UI Only)
- Comments (UI shown, not functional)
- Share functionality
- Add friend
- Edit profile
- Add evidence to goals

## Customization

### Updating Mock Data
Edit the JSON files in `MockData/` to change:
- User profiles
- Posts content
- Goals and bucket lists
- Friend relationships

### Changing Colors
Modify `Theme/Colors.swift` to adjust the color palette

### Typography Adjustments
Edit `Theme/Typography.swift` to change font sizes or weights

## Design Principles Applied

✓ **Clarity First** - Minimal clutter, content-focused layouts
✓ **Clean Aesthetic** - Generous white space, card-based design
✓ **Consistent Visual Language** - Unified colors and typography
✓ **Efficient Navigation** - Bottom tab bar for quick access
✓ **Motivational Focus** - Celebrate achievements with success colors
✓ **Accessibility** - 44pt touch targets, VoiceOver ready, Dynamic Type support

## Known Limitations

This is a **mock frontend only**:
- No backend API integration
- No persistent storage (data resets on app restart)
- No actual authentication
- Limited error handling
- No network calls
- Comments are placeholder UI only

## Next Steps for Production

To make this production-ready, you would need to:

1. **Backend Integration**
   - RESTful API implementation
   - Authentication (Supabase/Firebase)
   - PostgreSQL database
   - File storage for images

2. **Data Persistence**
   - Replace MockDataLoader with API service layer
   - Implement Combine/async-await for network calls
   - Add caching with CoreData or Realm

3. **Additional Features**
   - Real-time comments
   - Push notifications
   - Image upload
   - Strava integration
   - User search and discovery

4. **Polish**
   - Loading states
   - Error handling
   - Offline support
   - Animation refinements

## License

This is a prototype/mock implementation for demonstration purposes.

## Credits

Design inspired by Instagram and Nike Run Club
Built with SwiftUI
Mock images from picsum.photos and pravatar.cc



