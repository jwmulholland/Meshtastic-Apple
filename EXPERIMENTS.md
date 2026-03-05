# Meshtastic App Experiments

Tracking structural changes to the Meshtastic-Apple codebase as we evaluate whether to build fresh or adapt existing code.

## Implementation Strategy

Changes are grouped by complexity and dependency. Start with Phase 1 (simple renames), then Phase 2 (content migration), then Phase 3 (UI restructuring).

---

## Phase 1: Tab Bar Renames (Low Risk)

### 1.1 Rename tabs in tab bar
- **Changes:**
  - "Mesh Map" → "Map"
  - "Connect" → "Device"
- **File/Component:** Tab bar configuration (likely same file/component)
- **Impact:** Cosmetic only, but "Device" better reflects future content
- **Dependencies:** None
- **Status:** Not started
- **Note:** Both renames can be done together since they're in the same UI component

---

## Phase 2: Content Migration (Medium Complexity)

### 2.1 Move device configuration from Settings to Device tab
- **From:** Settings tab
- **To:** Device tab (formerly Connect)
- **Content:** Device-specific configuration items
- **Impact:** Reduces clutter in Settings, consolidates device management
- **Dependencies:** Phase 1 complete
- **Status:** Not started

### 2.2 Hide connected device from Nodes list
- **Current behavior:** Connected device appears in Nodes list
- **New behavior:** Remove it from that list
- **Rationale:** User doesn't need to see their own device in a list of other nodes
- **Impact:** Cleaner Nodes list
- **Dependencies:** None
- **Status:** Not started

### 2.3 Move Node detail views to Device tab
- **Content to move:** All items currently under Node detail (Hardware, Node, Logs, Actions, Administration)
- **From:** Nodes list detail view
- **To:** Device tab as primary device management interface
- **Rationale:** Consolidates all device management in one place
- **Impact:** Major navigation restructure
- **Dependencies:** 2.1 complete
- **Status:** Not started

---

## Phase 3: Navigation Restructuring (High Complexity)

### 3.1 Combine channels and direct messages in Messages tab
- **Current:** Separate sections/lists for channels vs DMs
- **New:** Single unified list with filtering
- **Implementation:**
  - Default view: "All" (shows both channels and DMs)
  - Filter options: "All" | "Direct Messages" | "Channels"
  - Filter control: Menu/segmented control at top of list
- **Impact:** Major UX change to primary messaging interface
- **Dependencies:** None
- **Status:** Not started
- **Open questions:**
  - How to visually distinguish channels from DMs in unified list?
  - Sort order when mixing channels and DMs?

#### Includes Code Updates:
- Extend MessageDestination enum
- Create UnifiedMessageList.swift
- Create ConversationRow.swift         
- Rewrite Messages.swift
- Register new files in project.pbxproj

#### Need to verify recency sorting:
Send a message to someone lower in the list (like Pete or Markbot). After sending, that conversation should jump to the top of the list.

What we should see when messages exist:
- Timestamps on the right side of each row
- Last message preview below the name
- Unread blue dot on left when unread 

### 3.2 Move Nodes list to Messages tab as sub-navigation
- **Current:** Nodes is its own tab or separate navigation area
- **New:** Accessible from Messages tab via "Add+" button
- **Rationale:** Nodes are primarily about finding people to message
- **Impact:** Reduces top-level navigation complexity
- **Dependencies:** 2.2 and 2.3 complete (since we're changing what Nodes list contains)
- **Status:** Not started
- **Implementation notes:**
  - "Add+" button in Messages tab header
  - Opens Nodes list view
  - User can select node to start conversation

---

## Open Design Questions

### Q1: Starred/Favorited Contacts
**Question:** How do we differentiate starred/favorited contacts from all others in the unified Messages list?

**Options to explore:**
- Pin favorites to top of list
- Visual indicator (star icon, different background)
- Separate "Favorites" filter option in addition to All/DMs/Channels
- Quick access row above main list

**Decision:** TBD
**Priority:** Medium - affects Phase 3.1 implementation

---

## Testing Strategy

- Test each phase independently before moving to next
- Document findings after each experiment
- Take screenshots of before/after states
- Note any unexpected interactions or side effects

---

## Success Criteria

- Navigation feels more intuitive to non-technical users
- Device management is consolidated and easier to find
- Messaging interface is cleaner and more focused
- No loss of functionality from original app

---

## Rollback Plan

Each phase should be in its own branch. If an experiment doesn't work:
1. Document why in this file
2. Revert the branch
3. Evaluate alternative approaches
