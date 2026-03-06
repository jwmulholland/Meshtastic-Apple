# Meshtastic App Redesign - Exploration Phase

## Project Context
Redesigning Meshtastic iOS app for Burning Man 2026 and broader community use. Making mesh networking accessible to non-technical users while maintaining reliability for survival scenarios.

**Team:** James (design lead), Pablo (lead developer), Deb (designer/IA), Steven (implementation engineer)

**Current Phase:** Parallel experimentation - deciding whether to build fresh or adapt Meshtastic-Apple codebase

## Core Design Principles
1. **Center the person, not the device** - Radios are hot-swappable tools, not identity
2. **Community with known contacts** - Not a hobbyist node discovery tool
3. **Safety and privacy** - Manual controls, explicit consent, extreme-condition reliability

## Foundational Innovations
1. **App-level persistent identity** - User identity decoupled from radio hardware. One person, multiple radios, consistent identity across devices.
2. **Dirt-simple configuration** - Instant network onboarding without technical knowledge. Management of configurations to be portable and easily identifiable while remaining mostly hidden for most users.

## Current Navigation Structure
**Now:** Messages | Device | Nodes | Map | Settings

**Vision:** Messages | Map | Device | Settings

**Device tab** consolidates features from Connect + Nodes tabs, simplified for non-technical users. Nodes tab will be hidden once consolidation complete - its contact-relevant features move to Messages.

## Key Features (Not Yet Implemented)
- **Savable and Sharable Location Pins:** Easily marked and shared map locations with a named title. Multi-functional and backwards compatible (through markdown-like human-readable encoding)
- **Manual stealth mode:** User-controlled location sharing separate from precision settings

## Changes Made
- ✅ Renamed Connect → Device (file: DeviceView.swift to avoid naming collision)
- ✅ Renamed Mesh Map → Map
- ✅ Reordered tabs: Messages | Map | Nodes | Device | Settings
- ✅ Device tab: Moved Nodes detail view wholesale (Hardware, metrics, logs, administration)
- ✅ Device tab: Removed Actions section (Hide alerts, Remove from favorites)
- ✅ Messages: Unified list combining channels and direct messages
- ✅ Messages: Filter controls (All, Channels, Direct Messages)
- ✅ Messages: Recency sorting (most recent conversations first)
- ✅ Channel management: Gear icon in channel threads opens edit form
- ✅ Channel management: ••• menu with "Add Channel" and "Manage Channels"
- ✅ Channel management: Fixed UX issues (chevron icons, dismiss behavior)

## Architecture Notes
- SwiftUI views
- Connected to Meshtastic radio via Bluetooth (testing with Muziworks R1)
- Protocol Buffers for Meshtastic protocol
- Current codebase is radio-hobbyist focused - intentionally moving away from this

## What NOT to Break
- Bluetooth radio connection/pairing
- Core Meshtastic protocol handling
- Message send/receive functionality
- Data persistence layer

## Development Workflow
**Read before write:** Always explain existing code architecture before implementing changes. Treat Claude Code as senior engineer consultant, not autocomplete.

## Terminology Decisions
- "Device" not "Radio" or "Node" (less technical)
- "Map" not "Mesh Map" (simpler)
- Contacts, not Nodes (when referring to people)

## Next Iterations
1. Complete Nodes tab consolidation
2. Hide Nodes tab (move remaining contact features to Messages)
3. Messages: Add node/contact management via "Add+" button
4. Messages tab: implement contact-focused model
5. Implement contact verification and location controls
6. Review channel disabling behavior (role=0)

## Known Issues / Future Work
- Channel disabling behavior unclear (role=0 triggers deletion, needs UX review)
- Recency sorting needs testing with real message data:
  - Verify conversations reorder when new messages arrive
  - Confirm timestamps display correctly
  - Check unread blue dot behavior
- Device tab needs simplification pass