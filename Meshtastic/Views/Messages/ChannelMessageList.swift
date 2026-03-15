//
//  ChannelMessageList.swift
//  Meshtastic
//
//  Created by Garth Vander Houwen on 12/24/21.
//

import CoreData
import MeshtasticProtobufs
import OSLog
import SwiftUI

struct ChannelMessageList: View {
	@EnvironmentObject var appState: AppState
	@Environment(\.scenePhase) var scenePhase
	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var accessoryManager: AccessoryManager
	@FocusState var messageFieldFocused: Bool
	@ObservedObject var myInfo: MyInfoEntity
	@ObservedObject var channel: ChannelEntity
	var node: NodeInfoEntity?
	@State private var replyMessageId: Int64 = 0
	@State private var redrawTapbacksTrigger = UUID()
	@AppStorage("preferredPeripheralNum") private var preferredPeripheralNum = -1
	@State private var messageToHighlight: Int64 = 0
	@FetchRequest private var allPrivateMessages: FetchedResults<MessageEntity>
	@State private var showingChannelConfig = false
	
	init(myInfo: MyInfoEntity, channel: ChannelEntity, node: NodeInfoEntity? = nil) {
		self.myInfo = myInfo
		self.channel = channel
		self.node = node
		
		let request: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
		request.sortDescriptors = [
			NSSortDescriptor(keyPath: \MessageEntity.messageTimestamp, ascending: true)
		]
		request.predicate = NSPredicate(
			format: "channel == %ld AND toUser == nil AND isEmoji == false",
			channel.index
		)
		_allPrivateMessages = FetchRequest(fetchRequest: request)
	}
	
	func handleInteractionComplete() {
		markMessagesAsRead()
		redrawTapbacksTrigger = UUID()
	}
	
	func markMessagesAsRead() {
		do {
			for unreadMessage in allPrivateMessages.filter({ !$0.read }) {
				unreadMessage.read = true
			}
			try context.save()
			Logger.data.info("📖 [App] All unread messages marked as read.")
			appState.unreadChannelMessages = myInfo.unreadMessages
			context.refresh(myInfo, mergeChanges: true)
		} catch {
			Logger.data.error("Failed to read messages: \(error.localizedDescription, privacy: .public)")
		}
	}
	
	private func routerIsShowingThisChannel() -> Bool {
		guard appState.router.navigationState.selectedTab == .messages else { return false }
		return scenePhase == .active
	}
	
	var body: some View {
		let messages: [MessageEntity] = Array(allPrivateMessages)

		let previousByID: [Int64: MessageEntity?] = {
			var dict = [Int64: MessageEntity?]()
			var prev: MessageEntity?
			for m in messages { dict[m.messageId] = prev; prev = m }
			return dict
		}()

		NavigationStack {
		ScrollViewReader { scrollView in
			ScrollView {
				LazyVStack {
					ForEach(messages, id: \.messageId) { message in
						let previousMessage: MessageEntity? = previousByID[message.messageId] ?? nil
						
						ChannelMessageRow(
							message: message,
							allMessages: allPrivateMessages,
							previousMessage: previousMessage,
							preferredPeripheralNum: preferredPeripheralNum,
							channel: channel,
							replyMessageId: $replyMessageId,
							messageFieldFocused: $messageFieldFocused,
							messageToHighlight: $messageToHighlight,
							scrollView: scrollView,
							onInteractionComplete: handleInteractionComplete
						)
						.onAppear {
							if !message.read && UIApplication.shared.applicationState == .active {
								message.read = true
								LocalNotificationManager().cancelNotificationForMessageId(message.messageId)
								DispatchQueue.main.async {
									markMessagesAsRead()
									scrollView.scrollTo("bottomAnchor", anchor: .bottom)
								}
							}
						}
					}
					Color.clear
						.frame(height: 1)
						.id("bottomAnchor")
				}
			}
			.defaultScrollAnchor(.bottom)
			.defaultScrollAnchorTopAlignment()
			.defaultScrollAnchorBottomSizeChanges()
			.scrollDismissesKeyboard(.immediately)
			.onChange(of: messageFieldFocused) {
				if messageFieldFocused {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
						scrollView.scrollTo("bottomAnchor", anchor: .bottom)
					}
				}
			}
			TextMessageField(
				destination: .channel(channel),
				replyMessageId: $replyMessageId,
				isFocused: $messageFieldFocused
			)
		}
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .principal) {
				HStack {
					CircleText(text: String(channel.index), color: .accentColor, circleSize: 44).fixedSize()
					Text(String(channel.name ?? "Unknown").camelCaseToWords()).font(.headline)
				}
			}
			ToolbarItem(placement: .navigationBarTrailing) {
				ZStack {
					ConnectedDevice(
						deviceConnected: accessoryManager.isConnected,
						name: accessoryManager.activeConnection?.device.shortName ?? "?",
						mqttProxyConnected: accessoryManager.mqttProxyConnected && (channel.uplinkEnabled || channel.downlinkEnabled),
						mqttUplinkEnabled: channel.uplinkEnabled,
						mqttDownlinkEnabled: channel.downlinkEnabled,
						mqttTopic: accessoryManager.mqttManager.topic
					)
				}
			}
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					showingChannelConfig = true
				} label: {
					Image(systemName: "gear")
				}
			}
		}
		.navigationDestination(isPresented: $showingChannelConfig) {
			ChannelEditView(channel: channel, node: node)
		}
		} // NavigationStack
	}
}
