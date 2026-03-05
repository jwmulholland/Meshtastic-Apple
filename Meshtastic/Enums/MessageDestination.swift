import CoreData

/// Helper abstraction for sharing functionality between channel and direct messaging.
enum MessageDestination {
	case user(UserEntity)
	case channel(ChannelEntity)

	var userNum: Int64 {
		switch self {
		case let .user(user): return user.num
		case .channel: return 0
		}
	}

	var channelNum: Int32 {
		switch self {
		case .user: return 0
		case let .channel(channel): return channel.index
		}
	}
}

// MARK: - Hashable + Equatable + Identifiable

extension MessageDestination: Hashable, Equatable {
	static func == (lhs: MessageDestination, rhs: MessageDestination) -> Bool {
		switch (lhs, rhs) {
		case (.channel(let a), .channel(let b)): return a == b
		case (.user(let a), .user(let b)): return a == b
		default: return false
		}
	}
	func hash(into hasher: inout Hasher) {
		switch self {
		case .channel(let c): hasher.combine(c)
		case .user(let u): hasher.combine(u)
		}
	}
}

extension MessageDestination: Identifiable {
	var id: NSManagedObjectID {
		switch self {
		case .channel(let c): return c.objectID
		case .user(let u): return u.objectID
		}
	}
}

// MARK: - Computed helpers

extension MessageDestination {
	private static let restrictedChannelNames: Set<String> = ["gpio", "mqtt", "serial", "admin"]

	var isMessagable: Bool {
		switch self {
		case .channel(let c):
			return !Self.restrictedChannelNames.contains(c.name?.lowercased() ?? "")
		case .user:
			return true
		}
	}

	var displayName: String {
		switch self {
		case .channel(let c):
			let name = c.name ?? ""
			if name.isEmpty { return c.role == 1 ? "Primary Channel" : "Channel \(c.index)" }
			return name.camelCaseToWords()
		case .user(let u):
			return u.longName ?? u.shortName ?? "Unknown"
		}
	}

	var mostRecentMessage: MessageEntity? {
		switch self {
		case .channel(let c): return c.mostRecentPrivateMessage
		case .user(let u): return u.mostRecentMessage
		}
	}

	var mostRecentTimestamp: Date {
		Date(timeIntervalSince1970: TimeInterval(mostRecentMessage?.messageTimestamp ?? 0))
	}

	var unreadCount: Int {
		switch self {
		case .channel(let c): return c.unreadMessages
		case .user(let u): return u.unreadMessages
		}
	}
}
