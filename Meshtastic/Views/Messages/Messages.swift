//
//  Messages.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 8/29/23.
//

import SwiftUI
import CoreData
import OSLog

struct Messages: View {

	@Environment(\.managedObjectContext) var context
	@ObservedObject var router: Router
	@Binding var unreadChannelMessages: Int
	@Binding var unreadDirectMessages: Int
	@State var node: NodeInfoEntity?
	@State private var destinationSelection: MessageDestination?

	var body: some View {
		NavigationSplitView {
			UnifiedMessageList(node: $node, selection: $destinationSelection)
				.navigationTitle("Messages")
				.navigationBarTitleDisplayMode(.large)
				.navigationBarItems(leading: MeshtasticLogo())
		} detail: {
			switch destinationSelection {
			case .channel(let channel):
				if let myInfo = node?.myInfo {
					ChannelMessageList(myInfo: myInfo, channel: channel)
				} else {
					ContentUnavailableView("No device connected", systemImage: "antenna.radiowaves.left.and.right.slash")
				}
			case .user(let user):
				UserMessageList(user: user)
			case nil:
				ContentUnavailableView("Select a conversation", systemImage: "message")
			}
		}
		.onChange(of: router.navigationState) { setupNavigationState() }
		.onAppear { setupNavigationState() }
	}

	private func setupNavigationState() {
		let nodeId = Int64(UserDefaults.preferredPeripheralNum)
		if nodeId > 0 {
			node = getNodeInfo(id: nodeId, context: context)
		}

		switch router.navigationState.messages {
		case .channels(channelId: let channelId, messageId: _):
			guard let channelId else { return }
			if let channel = node?.myInfo?.channels?
				.compactMap({ $0 as? ChannelEntity })
				.first(where: { $0.id == channelId }) {
				destinationSelection = .channel(channel)
			}
		case .directMessages(userNum: let userNum, messageId: _):
			guard let userNum else { return }
			let user = getUser(id: userNum, context: context)
			destinationSelection = .user(user)
		case nil:
			break
		}
	}
}
