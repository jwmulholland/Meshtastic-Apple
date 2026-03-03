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
2. **Preset/QR code configuration** - Instant network onboarding without technical knowledge

## Current Navigation Structure
**Now:** Messages | Device | Nodes | Map | Settings

**Vision:** Messages | Map | Device | Settings

**Device tab** consolidates features from Connect + Nodes tabs, simplified for non-technical users. Nodes tab will be hidden once consolidation complete - its contact-relevant features move to Messages.

## Key Features (Not Yet Implemented)
- **Ping system:** "Flares" (urgent signals) + "Beacons" (social invitations)
- **Contact verification:** Track in-person vs. remote additions with verification checkmarks
- **Location precision controls:** Per-contact choice of exact GPS, approximate, or general area
- **Manual stealth mode:** User-controlled location sharing separate from precision settings

## Changes Made
- ✅ Renamed Connect → Device (file: Device.swift)
- ✅ Renamed Mesh Map → Map
- 🔄 Moving Nodes detail view wholesale to Device tab
- 🔄 Filtering connected device out of Nodes list
- ⏳ Will hide Nodes tab after consolidation

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
1. Complete Device tab consolidation
2. Simplify Device tab (remove technical metadata, keep functional controls)
3. Hide Nodes tab
4. Messages tab: implement contact-focused model
5. Contact verification and location controls