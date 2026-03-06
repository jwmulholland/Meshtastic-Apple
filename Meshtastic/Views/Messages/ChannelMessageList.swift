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
	@State private var replyMessageId: Int64 = 0
	@State private var redrawTapbacksTrigger = UUID()
	@AppStorage("preferredPeripheralNum") private var preferredPeripheralNum = -1
	@State private var messageToHighlight: Int64 = 0
	@FetchRequest private var allPrivateMessages: FetchedResults<MessageEntity>

	// Channel config sheet state
	@State private var channelFormTitle = "Edit Channel"
	@State private var showingChannelConfig = false
	@State private var channelIndex: Int32 = 0
	@State private var channelName = ""
	@State private var channelKeySize = 16
	@State private var channelKey = "AQ=="
	@State private var channelRole = 0
	@State private var uplink = false
	@State private var downlink = false
	@State private var positionPrecision = 32.0
	@State private var preciseLocation = true
	@State private var positionsEnabled = true
	@State private var hasChanges = false
	@State private var hasValidKey = true
	@State private var supportedVersion = true
	private let minimumVersion = "2.2.24"
	
	init(myInfo: MyInfoEntity, channel: ChannelEntity) {
		self.myInfo = myInfo
		self.channel = channel
		
		// Configure fetch request here
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
	
	private func populateChannelState() {
		channelIndex = channel.index
		channelRole = Int(channel.role)
		let key = channel.psk?.base64EncodedString() ?? ""
		channelKey = key
		if key.isEmpty {
			channelKeySize = 0
		} else if key == "AQ==" {
			channelKeySize = -1
		} else if key.count == 4 {
			channelKeySize = 1
		} else if key.count == 24 {
			channelKeySize = 16
		} else if key.count == 32 {
			channelKeySize = 24
		} else if key.count == 44 {
			channelKeySize = 32
		}
		channelName = channel.name ?? ""
		uplink = channel.uplinkEnabled
		downlink = channel.downlinkEnabled
		positionPrecision = Double(channel.positionPrecision)
		if !supportedVersion && channelRole == 1 {
			positionPrecision = 32
			preciseLocation = true
			positionsEnabled = true
			if channelKey == "AQ==" { positionPrecision = 14; preciseLocation = false }
		} else if !supportedVersion && channelRole == 2 {
			positionPrecision = 0; preciseLocation = false; positionsEnabled = false
		} else {
			if channelKey == "AQ==" {
				preciseLocation = false
				if (positionPrecision > 0 && positionPrecision < 11) || positionPrecision > 14 { positionPrecision = 14 }
			} else if positionPrecision == 32 {
				preciseLocation = true; positionsEnabled = true
			} else {
				preciseLocation = false
			}
			positionsEnabled = positionPrecision != 0
		}
		channelFormTitle = "Edit Channel"
		hasChanges = false
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
		// Cast allPrivateMessages to an array for easier indexing and ForEach.
		let messages: [MessageEntity] = Array(allPrivateMessages)

		// Precompute previous message
		let previousByID: [Int64: MessageEntity?] = {
			var dict = [Int64: MessageEntity?]()
			var prev: MessageEntity?
			for m in messages { dict[m.messageId] = prev; prev = m }
			return dict
		}()

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
							  // Only mark as read if the app is in the foreground
							  if !message.read && UIApplication.shared.applicationState == .active {
								  message.read = true
								  LocalNotificationManager().cancelNotificationForMessageId(message.messageId)
								  // Race condition, sometimes the app doesn't update unread count if we run this too early
								  // So, run it in the main queue after everything saves and stabilizes
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
					populateChannelState()
					showingChannelConfig = true
				} label: {
					Image(systemName: "gear")
				}
			}
		}
		.sheet(isPresented: $showingChannelConfig) {
			ChannelForm(
				title: channelFormTitle,
				channelIndex: $channelIndex,
				channelName: $channelName,
				channelKeySize: $channelKeySize,
				channelKey: $channelKey,
				channelRole: $channelRole,
				uplink: $uplink,
				downlink: $downlink,
				positionPrecision: $positionPrecision,
				preciseLocation: $preciseLocation,
				positionsEnabled: $positionsEnabled,
				hasChanges: $hasChanges,
				hasValidKey: $hasValidKey,
				supportedVersion: $supportedVersion
			)
			.presentationDetents([.large])
			.presentationDragIndicator(.visible)
			.onFirstAppear {
				supportedVersion = accessoryManager.checkIsVersionSupported(forVersion: minimumVersion)
			}
			HStack {
				Button {
					guard let currentNode = getNodeInfo(id: Int64(preferredPeripheralNum), context: context) else { return }
					var ch = Channel()
					ch.index = channel.index
					ch.role = ChannelRoles(rawValue: channelRole)?.protoEnumValue() ?? .secondary
					ch.settings.name = channelName
					ch.settings.psk = Data(base64Encoded: channelKey) ?? Data()
					ch.settings.uplinkEnabled = uplink
					ch.settings.downlinkEnabled = downlink
					ch.settings.moduleSettings.positionPrecision = UInt32(positionPrecision)
					channel.role = Int32(channelRole)
					channel.name = channelName
					channel.psk = Data(base64Encoded: channelKey) ?? Data()
					channel.uplinkEnabled = uplink
					channel.downlinkEnabled = downlink
					channel.positionPrecision = Int32(positionPrecision)
					guard let mutableChannels = myInfo.channels?.mutableCopy() as? NSMutableOrderedSet else { return }
					if mutableChannels.contains(channel) {
						let replaceChannel = mutableChannels.first(where: { channel.psk == ($0 as AnyObject).psk && channel.name == ($0 as AnyObject).name })
						mutableChannels.replaceObject(at: mutableChannels.index(of: replaceChannel as Any), with: channel)
					} else {
						mutableChannels.add(channel)
					}
					myInfo.channels = mutableChannels.copy() as? NSOrderedSet
					context.refresh(channel, mergeChanges: true)
					if ch.role != Channel.Role.disabled {
						do {
							try context.save()
							Logger.data.info("💾 Saved Channel: \(ch.settings.name, privacy: .public)")
						} catch {
							context.rollback()
							Logger.data.error("Unresolved Core Data error saving channel: \(error as NSError, privacy: .public)")
						}
					} else {
						for object in channel.allPrivateMessages { context.delete(object) }
						let nodesFetch = NSFetchRequest<NodeInfoEntity>(entityName: "NodeInfoEntity")
						let allNodes = (try? context.fetch(nodesFetch)) ?? []
						for n in allNodes where n.channel == ch.index { context.delete(n) }
						context.delete(channel)
						do {
							try context.save()
							Logger.data.info("💾 Deleted Channel: \(ch.settings.name, privacy: .public)")
						} catch {
							context.rollback()
							Logger.data.error("Unresolved Core Data error deleting channel: \(error as NSError, privacy: .public)")
						}
					}
					Task {
						_ = try await accessoryManager.saveChannel(channel: ch, fromUser: currentNode.user!, toUser: currentNode.user!)
						Task { @MainActor in
							showingChannelConfig = false
							hasChanges = false
						}
						accessoryManager.mqttManager.connectFromConfigSettings(node: currentNode)
					}
				} label: {
					Label("Save", systemImage: "square.and.arrow.down")
				}
				.disabled(!accessoryManager.isConnected)
				.buttonStyle(.bordered)
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.padding(.bottom)
				#if targetEnvironment(macCatalyst)
				Button { showingChannelConfig = false } label: {
					Label("Close", systemImage: "xmark")
				}
				.buttonStyle(.bordered)
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.padding(.bottom)
				#endif
			}
		}
	}
}
