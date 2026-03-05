import SwiftUI

struct ConversationRow: View {
	let destination: MessageDestination
	let node: NodeInfoEntity?

	var body: some View {
		switch destination {
		case .channel(let channel): ChannelConversationRow(channel: channel)
		case .user(let user):       UserConversationRow(user: user)
		}
	}
}

private struct ChannelConversationRow: View {
	@ObservedObject var channel: ChannelEntity

	var body: some View {
		let mostRecent = channel.mostRecentPrivateMessage
		let hasUnread = channel.unreadMessages > 0
		let localeDateFormat = DateFormatter.dateFormat(fromTemplate: "yyMMdd", options: 0, locale: Locale.current)
		let dateFormatString = localeDateFormat ?? "MM/dd/YY"
		let lastMessageTime = Date(timeIntervalSince1970: TimeInterval(mostRecent?.messageTimestamp ?? 0))
		let lastMessageDay = Calendar.current.dateComponents([.day], from: lastMessageTime).day ?? 0
		let currentDay = Calendar.current.dateComponents([.day], from: Date()).day ?? 0

		HStack {
			Image(systemName: "circle.fill")
				.opacity(hasUnread ? 1 : 0)
				.font(.system(size: 10))
				.foregroundColor(.accentColor)
				.brightness(0.2)
			CircleText(text: String(channel.index), color: .accentColor)
				.brightness(0.2)
			VStack(alignment: .leading) {
				HStack {
					ChannelLock(channel: channel)
					Text(MessageDestination.channel(channel).displayName)
						.font(.headline)
					Spacer()
					if channel.mute { Image(systemName: "bell.slash") }
					if mostRecent != nil {
						timestampView(day: lastMessageDay, currentDay: currentDay,
									  time: lastMessageTime, dateFormat: dateFormatString)
					}
				}
				if let payload = mostRecent?.messagePayload {
					Text(payload)
						.font(.footnote)
						.foregroundColor(.secondary)
						.lineLimit(1)
				}
			}
		}
	}
}

private struct UserConversationRow: View {
	@ObservedObject var user: UserEntity

	var body: some View {
		let mostRecent = user.mostRecentMessage
		let hasUnread = user.unreadMessages > 0
		let localeDateFormat = DateFormatter.dateFormat(fromTemplate: "yyMMdd", options: 0, locale: Locale.current)
		let dateFormatString = localeDateFormat ?? "MM/dd/YY"
		let lastMessageTime = Date(timeIntervalSince1970: TimeInterval(mostRecent?.messageTimestamp ?? 0))
		let lastMessageDay = Calendar.current.dateComponents([.day], from: lastMessageTime).day ?? 0
		let currentDay = Calendar.current.dateComponents([.day], from: Date()).day ?? 0

		HStack {
			Image(systemName: "circle.fill")
				.opacity(hasUnread ? 1 : 0)
				.font(.system(size: 10))
				.foregroundColor(.accentColor)
				.brightness(0.2)
			CircleText(text: user.shortName ?? "?",
					   color: Color(UIColor(hex: UInt32(user.num))))
			VStack(alignment: .leading) {
				HStack {
					if user.pkiEncrypted {
						Image(systemName: user.keyMatch ? "lock.fill" : "key.slash")
							.foregroundColor(user.keyMatch ? .green : .red)
					} else {
						Image(systemName: "lock.open.fill").foregroundColor(.yellow)
					}
					Text(user.longName ?? "Unknown".localized)
						.font(.headline)
					if user.userNode?.favorite ?? false {
						Image(systemName: "star.fill").foregroundColor(.yellow)
					}
					Spacer()
					if mostRecent != nil {
						timestampView(day: lastMessageDay, currentDay: currentDay,
									  time: lastMessageTime, dateFormat: dateFormatString)
					}
				}
				if let payload = mostRecent?.messagePayload {
					Text(payload)
						.font(.footnote)
						.foregroundColor(.secondary)
						.lineLimit(1)
				}
			}
		}
	}
}

private func timestampView(day: Int, currentDay: Int, time: Date, dateFormat: String) -> some View {
	Group {
		if day == currentDay {
			Text(time, style: .time)
		} else if day == currentDay - 1 {
			Text("Yesterday")
		} else {
			Text(time.formattedDate(format: dateFormat))
		}
	}
	.font(.footnote)
	.foregroundColor(.secondary)
}
