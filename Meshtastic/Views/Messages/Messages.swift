//
//  Messages.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 8/29/23.
//

import SwiftUI
import CoreData
import OSLog
import MeshtasticProtobufs

struct Messages: View {

	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var accessoryManager: AccessoryManager
	@ObservedObject var router: Router
	@Binding var unreadChannelMessages: Int
	@Binding var unreadDirectMessages: Int
	@AppStorage("preferredPeripheralNum") private var preferredPeripheralNum = -1
	@State var node: NodeInfoEntity?
	@State private var destinationSelection: MessageDestination?

	// ••• menu sheet presentation
	@State private var showingManageChannels = false
	@State private var showingAddChannelForm = false

	// ChannelForm state (shared with Add Channel sheet)
	@State private var channelFormTitle = "Add Channel"
	@State private var channelIndex: Int32 = 0
	@State private var channelName = ""
	@State private var channelKeySize = 16
	@State private var channelKey = ""
	@State private var channelRole = 2
	@State private var uplink = false
	@State private var downlink = false
	@State private var positionPrecision = 0.0
	@State private var preciseLocation = false
	@State private var positionsEnabled = false
	@State private var hasChanges = false
	@State private var hasValidKey = true
	@State private var supportedVersion = true
	private let minimumVersion = "2.2.24"

	var body: some View {
		NavigationSplitView {
			UnifiedMessageList(node: $node, selection: $destinationSelection)
				.navigationTitle("Messages")
				.navigationBarTitleDisplayMode(.large)
				.navigationBarItems(leading: MeshtasticLogo(), trailing: menuButton)
		} detail: {
			switch destinationSelection {
			case .channel(let channel):
				if let myInfo = node?.myInfo {
					ChannelMessageList(myInfo: myInfo, channel: channel, node: node)
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
		.sheet(isPresented: $showingAddChannelForm) { addChannelSheet }
		.sheet(isPresented: $showingManageChannels) {
			NavigationStack { Channels(node: node, title: "Manage Channels", isSheet: true) }
		}
	}

	// MARK: - Menu button

	private var menuButton: some View {
		let channelCount = node?.myInfo?.channels?.count ?? 0
		return Menu {
			Button { addChannelAction() } label: {
				Label(channelCount >= 8 ? "Add Channel (max 8)" : "Add Channel", systemImage: "plus")
			}
			.disabled(channelCount >= 8)
			Button { showingManageChannels = true } label: {
				Label("Manage Channels", systemImage: "list.bullet")
			}
		} label: {
			Image(systemName: "ellipsis.circle")
		}
	}

	// MARK: - Add Channel flow

	private func addChannelAction() {
		let channelIndexes = (node?.myInfo?.channels?.array as? [ChannelEntity])?.map { Int($0.index) } ?? []
		let firstIndex = firstMissingChannelIndex(channelIndexes)
		channelKeySize = 16
		let key = generateChannelKey(size: channelKeySize)
		channelName = ""
		channelIndex = Int32(firstIndex)
		channelRole = 2
		channelKey = key
		positionsEnabled = false
		preciseLocation = false
		positionPrecision = 0
		uplink = false
		downlink = false
		channelFormTitle = "Add Channel"
		hasChanges = true
		showingAddChannelForm = true
	}

	// MARK: - Add Channel sheet

	@ViewBuilder
	private var addChannelSheet: some View {
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
			Button { saveNewChannel() } label: {
				Label("Save", systemImage: "square.and.arrow.down")
			}
			.disabled(!accessoryManager.isConnected)
			.buttonStyle(.bordered)
			.buttonBorderShape(.capsule)
			.controlSize(.large)
			.padding(.bottom)
			#if targetEnvironment(macCatalyst)
			Button { showingAddChannelForm = false } label: {
				Label("Close", systemImage: "xmark")
			}
			.buttonStyle(.bordered)
			.buttonBorderShape(.capsule)
			.controlSize(.large)
			.padding(.bottom)
			#endif
		}
	}

	private func saveNewChannel() {
		guard let currentNode = getNodeInfo(id: Int64(preferredPeripheralNum), context: context) else { return }

		let newChannel = ChannelEntity(context: context)
		newChannel.id = channelIndex
		newChannel.index = channelIndex
		newChannel.uplinkEnabled = uplink
		newChannel.downlinkEnabled = downlink
		newChannel.name = channelName
		newChannel.role = Int32(channelRole)
		newChannel.psk = Data(base64Encoded: channelKey) ?? Data()
		newChannel.positionPrecision = Int32(positionPrecision)

		var ch = Channel()
		ch.index = channelIndex
		ch.role = ChannelRoles(rawValue: channelRole)?.protoEnumValue() ?? .secondary
		ch.settings.name = channelName
		ch.settings.psk = Data(base64Encoded: channelKey) ?? Data()
		ch.settings.uplinkEnabled = uplink
		ch.settings.downlinkEnabled = downlink
		ch.settings.moduleSettings.positionPrecision = UInt32(positionPrecision)

		guard let mutableChannels = node?.myInfo?.channels?.mutableCopy() as? NSMutableOrderedSet else { return }
		mutableChannels.add(newChannel)
		node?.myInfo?.channels = mutableChannels.copy() as? NSOrderedSet
		context.refresh(newChannel, mergeChanges: true)
		do {
			try context.save()
			Logger.data.info("💾 Saved new Channel: \(ch.settings.name, privacy: .public)")
		} catch {
			context.rollback()
			Logger.data.error("Unresolved Core Data error saving new channel: \(error as NSError, privacy: .public)")
		}
		Task {
			_ = try await accessoryManager.saveChannel(channel: ch, fromUser: currentNode.user!, toUser: currentNode.user!)
			Task { @MainActor in
				showingAddChannelForm = false
				hasChanges = false
			}
			accessoryManager.mqttManager.connectFromConfigSettings(node: currentNode)
		}
	}

	// MARK: - Navigation state

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
