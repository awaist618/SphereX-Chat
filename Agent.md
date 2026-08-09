# SphereX --- Agent.md

## 1. Project Overview

**Project name:** SphereX\
**Tagline:** Smart Communication\
**Platform:** Flutter mobile application\
**Primary concept:** A modern real-time communication/chat application
that combines normal messaging with task-oriented conversations.

SphereX is designed for students, friends, project teams, and small
groups who want to communicate and turn important conversations into
actionable tasks.

### Core product idea

> SphereX doesn't just help users communicate; it helps them turn
> communication into action.

The application must feel like an original communication product. Do
**not** copy the UI, source code, layouts, branding, or exact
interaction patterns of WhatsApp, Telegram, Messenger, Discord, or other
existing applications.

------------------------------------------------------------------------

# 2. Main Unique Feature --- Smart Conversation / Tasks

The defining feature of SphereX is **Smart Tasks**.

Users can convert an important message into an actionable task.

Example conversation:

-   Ali: "We need to finish authentication tomorrow."
-   Awais: "I'll handle authentication."

The message can be converted into:

``` text
Task: Complete authentication
Assigned to: Awais
Due: Tomorrow
Status: Pending
Source: Original chat message
```

### Task properties

Each task can contain:

-   Task ID
-   Title
-   Description
-   Conversation ID
-   Source message ID
-   Created by
-   Assigned user
-   Due date/time
-   Status
-   Created timestamp
-   Completed timestamp

### Task statuses

-   Pending
-   In Progress
-   Completed
-   Cancelled

### Task screens

The main Tasks screen should provide:

-   All
-   Assigned to me
-   Created by me
-   Done

Tasks should visually communicate their status using checkboxes, icons,
labels, and subtle accent colors.

------------------------------------------------------------------------

# 3. Target Users

Primary users:

-   University students
-   Friends
-   Project teams
-   Small teams
-   Study groups
-   Freelancers
-   People coordinating small projects

The app should prioritize simplicity and fast communication.

------------------------------------------------------------------------

# 4. Authentication

Users must authenticate before accessing the main application.

Recommended authentication:

-   Email/password
-   Google Sign-In
-   Forgot password
-   Email verification if supported by backend
-   Logout

After registration, the user creates a public profile.

------------------------------------------------------------------------

# 5. User Identity and Contact System

SphereX should use **unique usernames** as the primary way to find
users.

Example:

``` text
Name: Awais Tariq
Username: @awais_07
```

### Username requirements

-   Must be unique
-   Lowercase preferred
-   Easy to search
-   No duplicate usernames
-   Validate allowed characters
-   Show `@username` in the UI

### Contact flow

``` text
Register
    ↓
Create Profile
    ↓
Choose Username
    ↓
Search @username
    ↓
Open Profile
    ↓
Send Contact Request
    ↓
Recipient Accepts
    ↓
User appears in Contacts
    ↓
Start Chat
```

### Contact request UI

Example:

``` text
Ahmed Khan
@ahmed_k

[ Accept ] [ Decline ]
```

### Optional QR contact feature

Every user can have a personal QR code.

Flow:

``` text
Profile
   ↓
My QR Code
   ↓
Another user scans QR
   ↓
Contact request
   ↓
Accept
   ↓
Chat
```

------------------------------------------------------------------------

# 6. Main Application Navigation

After login, use a bottom navigation structure.

Recommended tabs:

1.  Home
2.  Contacts
3.  Notifications
4.  Profile

The Home screen can contain communication categories such as:

-   Chats
-   Groups
-   Tasks
-   Calls

Do not overload the bottom navigation with too many destinations.

------------------------------------------------------------------------

# 7. Main Screens

## 7.1 Splash Screen

Purpose:

-   Display SphereX branding
-   Initialize authentication/session
-   Load basic application state

Visual direction:

-   Dark navy background
-   SphereX logo
-   Blue glow/accent
-   Short smooth animation

------------------------------------------------------------------------

## 7.2 Onboarding

Introduce the product in 2--3 pages.

Suggested concepts:

### Page 1

**Connect with people**

Real-time communication with friends and teams.

### Page 2

**Share anything**

Messages, images, files, and voice messages.

### Page 3

**Turn conversations into tasks**

Convert important messages into actionable tasks.

Use:

-   Large illustration
-   Short headline
-   Short description
-   Page indicators
-   Continue/Get Started button

------------------------------------------------------------------------

# 8. Home / Chat List UI

The Home screen should use a modern dark communication dashboard.

### Header

``` text
☰              SphereX              🔍
               Smart Communication
```

Possible actions:

-   Menu
-   Search
-   New chat

### Search field

Placeholder:

``` text
Search chats, users, groups...
```

### Category shortcuts

Use rounded icon buttons/cards:

-   Chats
-   Groups
-   Tasks
-   Calls

The active category should use the primary blue accent.

### Conversation item

Example:

``` text
[Avatar]  Ali Raza                         10:42 PM
          I'll send the files tonight.          2
```

Show:

-   Avatar
-   Online indicator
-   Name
-   Last message
-   Timestamp
-   Unread count

### Example conversations

Use realistic placeholder data during development:

-   Ali Raza
-   Flutter Team
-   Sana Fatima
-   Project Alpha
-   Bilal Ahmed
-   Design Squad
-   Hamza Khan

Do not hardcode these as permanent application data.

------------------------------------------------------------------------

# 9. Chat Screen

The chat screen is one of the most important screens.

## Header

Show:

-   Back button
-   Avatar
-   User/group name
-   Online/last seen status
-   Voice call button
-   Video call button
-   More menu

Example:

``` text
←  [Avatar] Ali Raza             📞  🎥  ⋮
              🟢 Online
```

## Message area

Support:

-   Text messages
-   Sent messages
-   Received messages
-   Timestamps
-   Read status
-   Reply
-   Edit
-   Delete
-   Copy
-   Reactions
-   Convert to task

### Sent message style

Use a blue rounded bubble aligned to the right.

### Received message style

Use a neutral/light or dark-slate rounded bubble aligned to the left.

Do not copy WhatsApp's exact bubble shapes or colors.

------------------------------------------------------------------------

# 10. Message Types

The data model should support:

-   Text
-   Image
-   File
-   Audio/voice
-   System message

Example:

``` text
message_type:
    text
    image
    file
    audio
    system
```

### File message

Display:

``` text
[PDF icon]
Project_Proposal.pdf
2.4 MB • PDF
```

### Image message

Display a rounded image preview.

### Voice message

Display:

``` text
▶  ───── waveform ─────
   00:12
```

------------------------------------------------------------------------

# 11. Message Composer

Bottom of chat:

``` text
[ + ] [ Type a message... ] [ 😊 ] [ 🎤 ]
```

The composer should support:

-   Text input
-   Attachment menu
-   Emoji
-   Voice recording
-   Send button when text is entered

Attachment menu can contain:

-   Camera
-   Gallery
-   File
-   Audio

------------------------------------------------------------------------

# 12. Contact System

Contacts screen should provide:

### Search

``` text
Search username...
```

### Sections

-   Contact requests
-   My contacts
-   Suggested/recent users

Each user card:

``` text
[Avatar]
Ahmed Khan
@ahmed_k
🟢 Online

[ Message ]
```

For non-contacts:

``` text
[ Add Contact ]
```

------------------------------------------------------------------------

# 13. User Profile

Profile should display:

-   Profile photo
-   Full name
-   Username
-   Bio
-   Online status
-   Shared media count if appropriate

Actions:

-   Message
-   Add Contact
-   Block
-   Report
-   Share Profile

Own profile:

-   Edit Profile
-   My QR Code
-   Settings
-   Logout

------------------------------------------------------------------------

# 14. Groups

Users can create group conversations.

Group features:

-   Group name
-   Group image
-   Group description
-   Members
-   Admin
-   Add members
-   Remove members
-   Leave group
-   Group permissions

Group chat should use the same message system as direct chat.

------------------------------------------------------------------------

# 15. Notifications

Notification screen should display:

-   Contact requests
-   New messages
-   Group invitations
-   Task assignments
-   Task completion
-   Other relevant activity

Example:

``` text
🔔 Ahmed sent you a message

📋 You were assigned:
Complete authentication

👥 You were added to Flutter Team
```

Unread notifications should have a visual indicator.

------------------------------------------------------------------------

# 16. Tasks Screen

The Tasks screen is a major product feature.

### Header

``` text
☑ My Tasks                         🔍 ⋮
```

### Filter chips

``` text
All
Assigned to me
Created by me
Done
```

### Task card

``` text
○ Complete authentication flow

  Assigned to
  [Avatar] Ali Raza

  Due Today
  11:59 PM
```

Completed task:

``` text
✓ Test real-time messaging

  Assigned to
  [Avatar] You

  Due Today
  11:59 PM
```

Use a floating action button for creating a task manually.

------------------------------------------------------------------------

# 17. Creating a Task from a Message

Message actions should include:

``` text
Reply
React
Copy
Edit
Delete
Create Task
```

When the user selects **Create Task**, open a form:

``` text
Create Task

Title
[ Complete authentication ]

Assigned to
[ Awais Tariq ▼ ]

Due date
[ 13 Aug 2026 ]

Description
[ Optional description ]

[ Create Task ]
```

The task should retain the source message ID so the user can navigate
back to the original message.

------------------------------------------------------------------------

# 18. Search

Global search should support:

-   Users
-   Usernames
-   Groups
-   Conversations
-   Messages

Search results should be clearly separated by category.

Example:

``` text
People
@ahmed_k

Groups
Flutter Team

Messages
"authentication"
```

------------------------------------------------------------------------

# 19. Calls

Calls can be represented in the UI even if full voice/video
infrastructure is implemented later.

Support architecture for:

-   Voice calls
-   Video calls
-   Call history
-   Missed calls

Call states:

-   Calling
-   Ringing
-   Connected
-   Ended
-   Missed

------------------------------------------------------------------------

# 20. Online Presence

Users should have:

-   Online
-   Offline
-   Last seen
-   Typing indicator

Example:

``` text
Ali Raza
🟢 Online
```

or:

``` text
Ali Raza
Last seen 10 minutes ago
```

Typing:

``` text
Ali Raza is typing...
```

------------------------------------------------------------------------

# 21. Read Receipts

Messages should support:

-   Sent
-   Delivered
-   Read

Use subtle indicators.

Avoid copying the exact visual treatment of other messaging apps.

------------------------------------------------------------------------

# 22. Themes and Colors

## Primary Color Palette

Use the following core colors consistently.

``` text
Primary Dark Deep Navy: #0A2540
Electric Blue:          #2979FF
Light Sky Blue:         #5B9CFF
Accent Amber Gold:      #FFB300
Success Green:          #00C48C
Danger Red:             #FF4C61
Background Off White:   #F5F7FA
Dark Background:       #0F1B2D
Card White:             #FFFFFF
Card Dark Slate:        #16233A
Text Primary:           #1A1D29
```

## Color roles

### #0A2540 --- Deep Navy

Use for:

-   Main branding
-   Dark headers
-   Navigation surfaces
-   Strong dark backgrounds

### #2979FF --- Electric Blue

Primary action color.

Use for:

-   Buttons
-   Active navigation
-   Send button
-   Selected tabs
-   Links
-   Active states
-   Floating action buttons

### #5B9CFF --- Light Sky Blue

Use for:

-   Secondary blue elements
-   Gradients
-   Highlights
-   Supporting visual accents

### #FFB300 --- Amber Gold

Use sparingly for:

-   Due dates
-   Warnings
-   Important attention indicators

Do not use amber as the main brand color.

### #00C48C --- Success Green

Use for:

-   Online indicators
-   Successful actions
-   Completed tasks
-   Success messages

### #FF4C61 --- Danger Red

Use for:

-   Delete
-   Errors
-   Failed states
-   Destructive actions

### #F5F7FA --- Off White

Use as the primary light-theme background.

### #0F1B2D --- Dark

Use as the primary dark-theme background.

### #FFFFFF --- White

Use for:

-   Light-theme cards
-   Light-theme surfaces
-   Text on dark/blue backgrounds where appropriate

### #16233A --- Dark Slate

Use for:

-   Dark-theme cards
-   Input backgrounds
-   Secondary surfaces

### #1A1D29 --- Text Primary

Use for primary text in the light theme.

------------------------------------------------------------------------

# 23. Dark Theme

Dark theme is a major part of the SphereX identity.

Recommended hierarchy:

``` text
App background       #0F1B2D
Header               #0A2540
Cards                #16233A
Primary action       #2979FF
Secondary blue       #5B9CFF
Primary text         #FFFFFF
Secondary text       #AAB7C8
Success              #00C48C
Danger               #FF4C61
Warning              #FFB300
```

Do not make every component pure black.

Use navy/slate layers to create depth.

------------------------------------------------------------------------

# 24. Light Theme

Recommended hierarchy:

``` text
App background       #F5F7FA
Cards                #FFFFFF
Header               #0A2540 or white depending on screen
Primary action       #2979FF
Primary text         #1A1D29
Secondary text       #667085
Borders              subtle neutral gray
Success              #00C48C
Danger               #FF4C61
Warning              #FFB300
```

------------------------------------------------------------------------

# 25. Typography

Use a clean modern sans-serif font.

Preferred:

-   Inter
-   Poppins
-   SF Pro-like system font where available

Typography hierarchy:

``` text
Screen title:        22–26 px, bold
Section title:       17–20 px, semibold
Body:                14–16 px
Caption:             11–13 px
Button:              14–16 px, semibold
Username:            13–15 px
```

Do not use overly decorative fonts.

------------------------------------------------------------------------

# 26. UI Style

Overall design language:

-   Modern
-   Clean
-   Premium
-   Minimal
-   Rounded
-   Slightly futuristic
-   Communication-focused
-   Professional but friendly

Use:

-   Rounded cards
-   Rounded buttons
-   Soft elevation/shadows
-   Consistent spacing
-   Clean icons
-   Large touch targets
-   Subtle animations

Avoid:

-   Excessive gradients
-   Excessive glassmorphism
-   Excessive shadows
-   Tiny buttons
-   Crowded screens
-   Too many colors
-   Copying another messaging application's layout

------------------------------------------------------------------------

# 27. Border Radius

Recommended values:

``` text
Small controls:      8 px
Inputs:              12–16 px
Cards:               16–20 px
Chat bubbles:        16–20 px
Large containers:    20–24 px
Buttons:             12–16 px
Bottom sheets:       24–28 px
```

Keep radius consistent throughout the application.

------------------------------------------------------------------------

# 28. Spacing System

Use an 8-point spacing system.

``` text
4   — very small
8   — small
12  — compact
16  — normal
20  — medium
24  — large
32  — section spacing
40+ — major spacing
```

Avoid arbitrary spacing values unless necessary.

------------------------------------------------------------------------

# 29. Icons

Use one consistent icon family.

Recommended Flutter option:

-   Material Icons

Icons should be:

-   Simple
-   Recognizable
-   Consistent
-   Appropriately sized

Typical icon sizes:

``` text
Small:      18 px
Normal:     22–24 px
Large:      28 px
Hero:       32–40 px
```

------------------------------------------------------------------------

# 30. Buttons

Primary button:

-   Electric Blue background
-   White text
-   Rounded corners
-   Medium/heavy font weight

Example:

``` text
┌─────────────────────────┐
│       Send Message      │
└─────────────────────────┘
```

Secondary button:

-   Transparent or dark-slate surface
-   Blue/white text depending on theme

Danger button:

-   Danger red only when the action is destructive.

------------------------------------------------------------------------

# 31. Floating Action Button

Use Electric Blue:

``` text
#2979FF
```

Typical actions:

-   New chat
-   New task
-   Add contact

Use a single clear icon.

Do not place too many floating buttons on one screen.

------------------------------------------------------------------------

# 32. Avatars

Avatar style:

-   Circular
-   Consistent size
-   Optional online status dot

Recommended sizes:

``` text
Chat list:       48–52 px
Chat header:     40–44 px
Profile:         90–120 px
Task assignment: 28–32 px
```

Online dot:

-   Green #00C48C

Offline:

-   No dot or subtle gray.

------------------------------------------------------------------------

# 33. Animations

Animations should be short and purposeful.

Recommended:

-   Fade transition
-   Slide transition
-   Scale for buttons
-   Message appearing animation
-   Typing indicator
-   Loading shimmer
-   Lottie for onboarding/splash if useful

Avoid long animations that slow communication.

------------------------------------------------------------------------

# 34. Loading, Empty, and Error States

Every major async screen must have proper states.

### Loading

Use:

-   Skeleton/shimmer
-   Circular progress where appropriate

### Empty chats

``` text
No conversations yet

Find someone by username and
start your first conversation.

[ Find People ]
```

### Empty tasks

``` text
No tasks yet

Turn important messages into
actionable tasks.

[ Create Task ]
```

### Error

Show a friendly message and retry action.

Example:

``` text
Something went wrong.

[ Try Again ]
```

Never leave the user on a blank screen.

------------------------------------------------------------------------

# 35. Backend Recommendation

Recommended backend:

**Supabase**

Use:

-   Supabase Auth
-   PostgreSQL
-   Supabase Realtime
-   Supabase Storage
-   Row Level Security

Recommended database tables:

``` text
profiles
conversations
conversation_members
messages
message_reactions
contacts
contact_requests
tasks
notifications
groups
group_members
calls
```

------------------------------------------------------------------------

# 36. Database Structure

## profiles

``` text
id
name
username
email
avatar_url
bio
is_online
last_seen
created_at
updated_at
```

## conversations

``` text
id
type
name
avatar_url
created_by
created_at
updated_at
```

`type`:

``` text
direct
group
```

## conversation_members

``` text
conversation_id
user_id
joined_at
role
```

## messages

``` text
id
conversation_id
sender_id
content
message_type
file_url
file_name
file_size
reply_to
created_at
updated_at
deleted_at
is_edited
```

## message_reactions

``` text
id
message_id
user_id
reaction
created_at
```

## contacts

``` text
id
user_id
contact_user_id
created_at
```

## contact_requests

``` text
id
sender_id
receiver_id
status
created_at
updated_at
```

Status:

``` text
pending
accepted
declined
blocked
```

## tasks

``` text
id
conversation_id
source_message_id
created_by
assigned_to
title
description
due_date
status
created_at
completed_at
```

## notifications

``` text
id
user_id
sender_id
type
title
body
reference_id
is_read
created_at
```

------------------------------------------------------------------------

# 37. Security

Use backend security properly.

Important requirements:

-   Never expose service-role keys in Flutter
-   Use environment/configuration for public configuration
-   Use Supabase Row Level Security
-   Users can only access conversations they belong to
-   Users can only edit/delete their own messages where permitted
-   Users can only modify their own profile
-   Tasks must respect conversation membership
-   Validate uploaded files
-   Apply reasonable file size/type restrictions
-   Never trust client-side authorization alone

------------------------------------------------------------------------

# 38. Flutter Architecture

Recommended architecture:

``` text
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   ├── services/
│   └── errors/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── chat/
│   ├── contacts/
│   ├── groups/
│   ├── tasks/
│   ├── notifications/
│   ├── profile/
│   └── calls/
│
├── models/
├── providers/
├── repositories/
├── routing/
└── main.dart
```

Keep business logic out of widgets whenever practical.

------------------------------------------------------------------------

# 39. State Management

Preferred:

-   Riverpod

Alternative:

-   Provider
-   Bloc

Do not mix multiple state-management systems without a strong reason.

------------------------------------------------------------------------

# 40. Recommended Packages

Packages may include:

``` text
flutter_riverpod
go_router
supabase_flutter
firebase_messaging
google_sign_in
image_picker
file_picker
cached_network_image
permission_handler
record
just_audio
uuid
intl
flutter_local_notifications
lottie
```

Only add packages that are actually needed.

Avoid unnecessary dependencies.

------------------------------------------------------------------------

# 41. Realtime Communication

Messages should appear without manually refreshing the screen.

Realtime flow:

``` text
User A sends message
        ↓
Flutter
        ↓
Supabase Database
        ↓
Supabase Realtime
        ↓
User B receives message
        ↓
Chat UI updates
```

The chat screen should listen to relevant conversation changes.

------------------------------------------------------------------------

# 42. File and Media Sharing

Supabase Storage can be used for:

-   Profile photos
-   Chat images
-   Documents
-   Audio files

Store the file in storage and save the resulting reference/URL in the
`messages` table.

Never store large binary files directly in PostgreSQL.

------------------------------------------------------------------------

# 43. Notifications

Use Firebase Cloud Messaging for push notifications.

Notification examples:

``` text
New message
Contact request
Task assigned
Task completed
Group invitation
```

Notifications should deep-link into the relevant screen when possible.

Example:

``` text
Notification
    ↓
Tap
    ↓
Chat screen
```

or:

``` text
Task notification
    ↓
Tap
    ↓
Task details
```

------------------------------------------------------------------------

# 44. Performance Requirements

The app should:

-   Avoid unnecessary rebuilds
-   Paginate long message histories
-   Compress large images
-   Cache remote images
-   Avoid loading all messages at once
-   Dispose controllers/listeners correctly
-   Avoid memory leaks
-   Handle slow networks gracefully

Chat should remain responsive even with many messages.

------------------------------------------------------------------------

# 45. Accessibility and Usability

Use:

-   Adequate contrast
-   Large enough touch targets
-   Clear labels
-   Readable text
-   Semantic labels where appropriate
-   Avoid relying only on color to communicate state

Buttons should be easy to tap on mobile devices.

------------------------------------------------------------------------

# 46. Error Handling

Handle:

-   No internet
-   Authentication failure
-   Invalid credentials
-   Upload failure
-   Message send failure
-   Database errors
-   Permission denial
-   Notification permission denial
-   Empty search results
-   User not found
-   Contact request already sent
-   Blocked users
-   Session expiration

Never allow an exception to crash the application.

------------------------------------------------------------------------

# 47. Example User Journey

``` text
Open SphereX
    ↓
Splash
    ↓
Login / Register
    ↓
Create Profile
    ↓
Choose @username
    ↓
Home
    ↓
Contacts
    ↓
Search @ahmed_k
    ↓
Open Ahmed's Profile
    ↓
Send Contact Request
    ↓
Ahmed Accepts
    ↓
Start Chat
    ↓
Send Message
    ↓
Share File
    ↓
Convert Important Message to Task
    ↓
Task appears in My Tasks
    ↓
Complete Task
    ↓
Notification sent
```

------------------------------------------------------------------------

# 48. Example Visual Direction

The main post-login UI should resemble a premium dark communication
dashboard.

A conceptual home screen can contain:

``` text
┌──────────────────────────────┐
│ ☰       SphereX          🔍  │
│       Smart Communication    │
│                              │
│ 🔍 Search chats, users...    │
│                              │
│ 💬 Chats  👥 Groups          │
│ 📋 Tasks  📞 Calls           │
│                              │
│ 👤 Ali Raza          10:42   │
│    I'll send the files... 2  │
│                              │
│ 👥 Flutter Team       9:15   │
│    Don't forget to push... 5 │
│                              │
│ 👤 Sana Fatima        8:50   │
│    That looks great!         │
│                              │
│                         ＋    │
│                              │
│ 🏠 Home Contacts 🔔 Profile  │
└──────────────────────────────┘
```

The chat screen:

``` text
┌──────────────────────────────┐
│ ←  Ali Raza     📞 🎥 ⋮      │
│    🟢 Online                 │
├──────────────────────────────┤
│                              │
│  Hey! How are you?           │
│                              │
│                I'm good! 😊  │
│                              │
│  Did you check the doc?      │
│                              │
│       I'll send updates soon │
│                              │
│  📄 Project_Proposal.pdf     │
│                              │
├──────────────────────────────┤
│ ＋  Type a message...   😊 🎤 │
└──────────────────────────────┘
```

Tasks:

``` text
┌──────────────────────────────┐
│ ☑ My Tasks               🔍  │
│                              │
│ All | Assigned | Created | ✓ │
│                              │
│ ○ Complete authentication    │
│   Assigned to Ali Raza       │
│   Due Today       11:59 PM   │
│                              │
│ ✓ Test real-time messaging   │
│   Assigned to You            │
│   Due Today       11:59 PM   │
│                              │
│ ○ Prepare presentation       │
│   Assigned to Sana           │
│   Due Tomorrow               │
│                         ＋    │
└──────────────────────────────┘
```

------------------------------------------------------------------------

# 49. Design Rules for AI Agents

When modifying or generating the application, follow these rules:

1.  Preserve the SphereX brand identity.
2.  Use the defined color palette.
3.  Prefer dark navy/slate surfaces instead of pure black.
4.  Use Electric Blue `#2979FF` for primary actions.
5.  Use Success Green `#00C48C` only for positive/success/online states.
6.  Use Danger Red `#FF4C61` only for destructive/error states.
7.  Use Amber `#FFB300` sparingly for warnings and due dates.
8.  Keep UI clean and spacious.
9.  Use consistent rounded corners.
10. Use consistent 8-point spacing.
11. Use Material icons or one consistent icon family.
12. Do not copy existing messaging apps.
13. Do not introduce random colors without a design reason.
14. Do not redesign already-approved screens unnecessarily.
15. Reuse components instead of duplicating UI code.
16. Keep business logic separate from presentation.
17. Handle loading, empty, error, and success states.
18. Never hardcode authentication or authorization logic.
19. Never expose private backend keys.
20. Keep the application stable before adding extra features.

------------------------------------------------------------------------

# 50. MVP Priority

If development time is limited, implement features in this order:

## Priority 1 --- Required

-   Authentication
-   User profiles
-   Unique usernames
-   Contact search
-   Contact requests
-   1-to-1 real-time chat
-   Message history
-   Online status
-   Basic notifications
-   APK build

## Priority 2 --- Important

-   Groups
-   Image sharing
-   File sharing
-   Voice messages
-   Message reactions
-   Reply/edit/delete
-   Dark/light theme

## Priority 3 --- Signature Feature

-   Convert message to task
-   Task assignment
-   Task due date
-   Task status
-   My Tasks screen
-   Task notifications

## Priority 4 --- Optional

-   QR contact
-   Voice calls
-   Video calls
-   Advanced search
-   Advanced privacy controls

A stable Priority 1 + Priority 3 implementation is more valuable than
many unfinished features.

------------------------------------------------------------------------

# 51. Submission Requirements

The final project must provide:

``` text
APK
Source Code ZIP
GitHub Repository
Minimum 5 screenshots
README.md
```

APK maximum:

``` text
50 MB
```

The final APK must be tested on a real Android device/emulator.

Before submission:

-   Test login
-   Test registration
-   Test profile
-   Test contact search
-   Test contact request
-   Test chat
-   Test realtime messages
-   Test media upload
-   Test tasks
-   Test notifications
-   Test dark/light mode
-   Test logout
-   Test app restart/session persistence
-   Check crashes
-   Check APK size

------------------------------------------------------------------------

# 52. README Requirements

README.md should include:

``` text
# SphereX

Smart Communication

## Overview

## Features

## Unique Feature

## Screenshots

## Tech Stack

## Packages

## Architecture

## Database Structure

## Setup Instructions

## Environment Configuration

## Supabase Configuration

## Firebase Configuration

## Running the Project

## Building APK

## Future Improvements

## Author
```

Do not put private API keys, passwords, service-role keys, or secrets in
the README or GitHub repository.

------------------------------------------------------------------------

# 53. Final Product Identity

SphereX should communicate three ideas immediately:

### Connect

Find and communicate with people.

### Communicate

Send real-time messages and media.

### Act

Turn important conversations into tasks.

The application should feel like a complete original communication
product rather than a basic chat clone.

**Brand statement:**

> SphereX --- Smart Communication

**Product statement:**

> Connect. Communicate. Turn conversations into action.
