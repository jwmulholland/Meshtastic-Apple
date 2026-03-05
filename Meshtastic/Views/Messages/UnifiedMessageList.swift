import SwiftUI
import CoreData

enum MessageFilter: String, CaseIterable {
	case all = "All"
	case channels = "Channels"
	case directMessages = "Direct Messages"
}

struct UnifiedMessageList: View {
	@EnvironmentObject var accessoryManager: AccessoryManager
	@Binding var node: NodeInfoEntity?
	@Binding var selection: MessageDestination?
	@State private var filter: MessageFilter = .all

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(keyPath: \ChannelEntity.index, ascending: true)],
		animation: .default
	) private var channels: FetchedResults<ChannelEntity>

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(key: "lastMessage", ascending: false)],
		animation: .default
	) private var users: FetchedResults<UserEntity>

	private var conversations: [MessageDestination] {
		let activeDeviceNum = accessoryManager.activeDeviceNum ?? 0

		let channelItems = channels
			.map { MessageDestination.channel($0) }
			.filter { $0.isMessagable }

		let userItems = users
			.filter { $0.num != activeDeviceNum }
			.map { MessageDestination.user($0) }

		let combined: [MessageDestination]
		switch filter {
		case .all:          combined = channelItems + userItems
		case .channels:     combined = channelItems
		case .directMessages: combined = userItems
		}

		return combined.sorted {
			if $0.mostRecentTimestamp != $1.mostRecentTimestamp {
				return $0.mostRecentTimestamp > $1.mostRecentTimestamp
			}
			return $0.channelNum < $1.channelNum || $0.userNum < $1.userNum
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			Picker("Filter", selection: $filter) {
				ForEach(MessageFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
			}
			.pickerStyle(.segmented)
			.padding(.horizontal)
			.padding(.vertical, 8)

			List(conversations, selection: $selection) { destination in
				NavigationLink(value: destination) {
					ConversationRow(destination: destination, node: node)
				}
				.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
				.frame(height: 62)
			}
			.listStyle(.plain)
		}
	}
}
