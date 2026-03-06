//
//  Channels.swift
//  Meshtastic Apple
//
//  Copyright(c) Garth Vander Houwen 4/8/22.
//

import CoreData
import MapKit
import MeshtasticProtobufs
import OSLog
import SwiftUI
import TipKit

func generateChannelKey(size: Int) -> String {
	var keyData = Data(count: size)
	_ = keyData.withUnsafeMutableBytes {
	  SecRandomCopyBytes(kSecRandomDefault, size, $0.baseAddress!)
	}
	return keyData.base64EncodedString()
}

struct Channels: View {

	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var accessoryManager: AccessoryManager
	@Environment(\.dismiss) private var goBack
	@Environment(\.sizeCategory) var sizeCategory
	@Environment(\.colorScheme) private var colorScheme

	var node: NodeInfoEntity?
	var title: String = "Channels"
	var isSheet: Bool = false

	@State var hasChanges = false
	@State var hasValidKey = true
	@State private var isPresentingSaveConfirm: Bool = false
	@State var channelIndex: Int32 = 0
	@State var channelName = ""
	@State var channelKeySize = 16
	@State var channelKey = "AQ=="
	@State var channelRole = 0
	@State var uplink = false
	@State var downlink = false
	@State var positionPrecision = 32.0
	@State var preciseLocation = true
	@State var positionsEnabled = true
	@State var supportedVersion = true
	@State var selectedChannel: ChannelEntity?
	@State private var pendingAddChannel: ChannelEntity?

	/// Minimum Version for granular position configuration
	@State var minimumVersion = "2.2.24"
	@State private var showingHelp = false
	@State var channelFormTitle = "Add Channel"

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(keyPath: \ChannelEntity.index, ascending: true)],
		animation: .default)
	private var fetchedChannels: FetchedResults<ChannelEntity>

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(key: "favorite", ascending: false),
						  NSSortDescriptor(key: "lastHeard", ascending: false),
						  NSSortDescriptor(key: "user.longName", ascending: true)],
		animation: .default)
	var nodes: FetchedResults<NodeInfoEntity>


	var body: some View {

		VStack {
			List {
				TipView(CreateChannelsTip(), arrowEdge: .bottom)
					.tipBackground(colorScheme == .dark ? Color(.systemBackground) : Color(.secondarySystemBackground))
					.listRowSeparator(.hidden)
				if isSheet {
					ForEach(fetchedChannels, id: \.self) { (channel: ChannelEntity) in
						NavigationLink(value: channel) {
							VStack(alignment: .leading) {
								HStack {
									CircleText(text: String(channel.index), color: .accentColor, circleSize: 45)
										.padding(.trailing, 5)
										.brightness(0.1)
									VStack {
										HStack {
											ChannelLock(channel: channel)
											if channel.name?.isEmpty ?? false {
												if channel.role == 1 {
													Text(String("PrimaryChannel").camelCaseToWords()).font(.headline)
												} else {
													Text(String("Channel \(channel.index)").camelCaseToWords()).font(.headline)
												}
											} else {
												Text(String(channel.name ?? "Channel \(channel.index)").camelCaseToWords()).font(.headline)
											}
										}
									}
								}
							}
						}
					}
				} else if node != nil && node?.myInfo != nil {
					ForEach(node?.myInfo?.channels?.array as? [ChannelEntity] ?? [], id: \.self) { (channel: ChannelEntity) in
						Button(action: {
							channelIndex = channel.index
							channelRole = Int(channel.role)
							channelKey = channel.psk?.base64EncodedString() ?? ""
							if channelKey.count == 0 {
								channelKeySize = 0
							} else if channelKey == "AQ==" {
								channelKeySize = -1
							} else if channelKey.count == 4 {
								channelKeySize = 1
							} else if channelKey.count == 24 {
								channelKeySize = 16
							} else if channelKey.count == 32 {
								channelKeySize = 24
							} else if channelKey.count == 44 {
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
								if channelKey == "AQ==" {
									positionPrecision = 14
									preciseLocation = false
								}
							} else if !supportedVersion && channelRole == 2 {
								positionPrecision = 0
								preciseLocation = false
								positionsEnabled = false
							} else {
								if channelKey == "AQ==" {
									preciseLocation = false
									if (positionPrecision > 0 && positionPrecision < 11) || positionPrecision > 14 {
										positionPrecision = 14
									}
								} else if positionPrecision == 32 {
									preciseLocation = true
									positionsEnabled = true
								} else {
									preciseLocation = false
								}
								if positionPrecision == 0 {
									positionsEnabled = false
								} else {
									positionsEnabled = true
								}
							}
							hasChanges = false
							channelFormTitle = "Edit Channel"
							selectedChannel = channel
						}) {
							HStack {
								VStack(alignment: .leading) {
									HStack {
										CircleText(text: String(channel.index), color: .accentColor, circleSize: 45)
											.padding(.trailing, 5)
											.brightness(0.1)
										VStack {
											HStack {
												ChannelLock(channel: channel)
												if channel.name?.isEmpty ?? false {
													if channel.role == 1 {
														Text(String("PrimaryChannel").camelCaseToWords()).font(.headline)
													} else {
														Text(String("Channel \(channel.index)").camelCaseToWords()).font(.headline)
													}
												} else {
													Text(String(channel.name ?? "Channel \(channel.index)").camelCaseToWords()).font(.headline)
												}
											}
										}
									}
								}
								Spacer()
								Image(systemName: "chevron.right")
									.font(.footnote.weight(.semibold))
									.foregroundColor(.secondary)
							}
						}
					}
				}
			}
			.navigationDestination(for: ChannelEntity.self) { channel in
				ChannelEditView(channel: channel, node: node)
			}
			.sheet(item: $selectedChannel, onDismiss: {
				if let sc = pendingAddChannel, sc.isInserted {
					context.delete(sc)
					pendingAddChannel = nil
				}
			}) { _ in
				ChannelForm(title: channelFormTitle, channelIndex: $channelIndex, channelName: $channelName, channelKeySize: $channelKeySize, channelKey: $channelKey, channelRole: $channelRole, uplink: $uplink, downlink: $downlink, positionPrecision: $positionPrecision, preciseLocation: $preciseLocation, positionsEnabled: $positionsEnabled, hasChanges: $hasChanges, hasValidKey: $hasValidKey, supportedVersion: $supportedVersion)
					.presentationDetents([.large])
					.presentationDragIndicator(.visible)
				.onFirstAppear {
					supportedVersion = accessoryManager.checkIsVersionSupported(forVersion: minimumVersion)
				}
				HStack {
					Button {
						var channel = Channel()
						channel.index = channelIndex
						channel.role = ChannelRoles(rawValue: channelRole)?.protoEnumValue() ?? .secondary
							channel.index = channelIndex
							channel.settings.name = channelName
							channel.settings.psk = Data(base64Encoded: channelKey) ?? Data()
							channel.settings.uplinkEnabled = uplink
							channel.settings.downlinkEnabled = downlink
							channel.settings.moduleSettings.positionPrecision = UInt32(positionPrecision)
							selectedChannel!.role = Int32(channelRole)
							selectedChannel!.index = channelIndex
							selectedChannel!.name = channelName
							selectedChannel!.psk = Data(base64Encoded: channelKey) ?? Data()
							selectedChannel!.uplinkEnabled = uplink
							selectedChannel!.downlinkEnabled = downlink
							selectedChannel!.positionPrecision = Int32(positionPrecision)

							guard let mutableChannels = node?.myInfo?.channels?.mutableCopy() as? NSMutableOrderedSet else {
								return
							}
							if mutableChannels.contains(selectedChannel as Any) {
								let replaceChannel = mutableChannels.first(where: { selectedChannel?.psk == ($0 as AnyObject).psk && selectedChannel?.name == ($0 as AnyObject).name})
								mutableChannels.replaceObject(at: mutableChannels.index(of: replaceChannel as Any), with: selectedChannel as Any)
							} else {
								mutableChannels.add(selectedChannel as Any)
							}
							node?.myInfo?.channels = mutableChannels.copy() as? NSOrderedSet
							context.refresh(selectedChannel!, mergeChanges: true)
						if channel.role != Channel.Role.disabled {
							do {
								try context.save()
								Logger.data.info("💾 Saved Channel: \(channel.settings.name, privacy: .public)")
							} catch {
								context.rollback()
								let nsError = error as NSError
								Logger.data.error("Unresolved Core Data error in the channel editor. Error: \(nsError, privacy: .public)")
							}
						} else {
							let objects = selectedChannel?.allPrivateMessages ?? []
							for object in objects {
								context.delete(object)
							}
							for node in nodes where node.channel == channel.index {
								context.delete(node)
							}
							context.delete(selectedChannel!)
							do {
								try context.save()
								Logger.data.info("💾 Deleted Channel: \(channel.settings.name, privacy: .public)")
							} catch {
								context.rollback()
								let nsError = error as NSError
								Logger.data.error("Unresolved Core Data error in the channel editor. Error: \(nsError, privacy: .public)")
							}
						}
						Task {
							_ = try await accessoryManager.saveChannel(channel: channel, fromUser: node!.user!, toUser: node!.user!)
							Task { @MainActor in
								pendingAddChannel = nil
								selectedChannel = nil
								channelName = ""
								channelRole	= 2
								hasChanges = false
							}
							accessoryManager.mqttManager.connectFromConfigSettings(node: node!)
						}
					} label: {
						Label("Save", systemImage: "square.and.arrow.down")
					}
					.disabled(!accessoryManager.isConnected)// || !hasChanges)// !hasValidKey)
					.buttonStyle(.bordered)
					.buttonBorderShape(.capsule)
					.controlSize(.large)
					.padding(.bottom)
					#if targetEnvironment(macCatalyst)
					Button {
						goBack()
					} label: {
						Label("Close", systemImage: "xmark")
					}
					.buttonStyle(.bordered)
					.buttonBorderShape(.capsule)
					.controlSize(.large)
					.padding(.bottom)
					#endif
				}
			}
			if node?.myInfo?.channels?.array.count ?? 0 < 8 && node != nil {

				Button {
					let channelIndexes = node?.myInfo?.channels?.compactMap({(ch) -> Int in
						return (ch as AnyObject).index
					})
					let firstChannelIndex = firstMissingChannelIndex(channelIndexes ?? [])
					channelKeySize = 16
					let key = generateChannelKey(size: channelKeySize)
					channelName = ""
					channelIndex = Int32(firstChannelIndex)
					channelRole = 2
					channelKey = key
					positionsEnabled = false
					preciseLocation = false
					positionPrecision = 0
					uplink = false
					downlink = false

					let newChannel = ChannelEntity(context: context)
					newChannel.id = channelIndex
					newChannel.index = channelIndex
					newChannel.uplinkEnabled = uplink
					newChannel.downlinkEnabled = downlink
					newChannel.name = channelName
					newChannel.role = Int32(channelRole)
					newChannel.psk = Data(base64Encoded: channelKey) ?? Data()
					newChannel.positionPrecision = Int32(positionPrecision)
					channelFormTitle = "Add Channel"
					pendingAddChannel = newChannel
					selectedChannel = newChannel
					hasChanges = true

				} label: {
					Label("Add Channel", systemImage: "plus.square")
				}
				.buttonStyle(.bordered)
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.padding()
			}
		}
		.sheet(isPresented: $showingHelp) {
			ChannelsHelp()
				.presentationDetents([.large])
				.presentationDragIndicator(.visible)
		}
		.safeAreaInset(edge: .bottom, alignment: .leading) {
			HStack {
				Button(action: {
					withAnimation {
						showingHelp = !showingHelp
					}
				}) {
					Image(systemName: !showingHelp ? "questionmark.circle" : "questionmark.circle.fill")
						.padding(.vertical, 5)
				}
				.tint(Color(UIColor.secondarySystemBackground))
				.foregroundColor(.accentColor)
				.buttonStyle(.borderedProminent)
			}
			.controlSize(.regular)
			.padding(5)
		}
		.padding(.bottom, 5)
		.navigationTitle(title)
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				ConnectedDevice(deviceConnected: accessoryManager.isConnected, name: accessoryManager.activeConnection?.device.shortName ?? "?")
			}
			if isSheet {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button("Done") { goBack() }
				}
			}
		}
	}
}

fileprivate struct ChannelEditView: View {
	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var accessoryManager: AccessoryManager
	@Environment(\.dismiss) private var dismiss
	@ObservedObject var channel: ChannelEntity
	var node: NodeInfoEntity?

	@State private var channelIndex: Int32
	@State private var channelName: String
	@State private var channelKeySize: Int
	@State private var channelKey: String
	@State private var channelRole: Int
	@State private var uplink: Bool
	@State private var downlink: Bool
	@State private var positionPrecision: Double
	@State private var preciseLocation: Bool
	@State private var positionsEnabled: Bool
	@State private var hasChanges = false
	@State private var hasValidKey = true
	@State private var supportedVersion = true
	private let minimumVersion = "2.2.24"

	// Original values captured at open time — used by Revert.
	// Must be @State so SwiftUI only initialises them once; plain `let` would be
	// re-computed from the (now-autosaved) entity on every @ObservedObject re-render.
	@State private var originalIndex: Int32
	@State private var originalName: String
	@State private var originalKeySize: Int
	@State private var originalKey: String
	@State private var originalRole: Int
	@State private var originalUplink: Bool
	@State private var originalDownlink: Bool
	@State private var originalPositionPrecision: Double
	@State private var originalPreciseLocation: Bool
	@State private var originalPositionsEnabled: Bool

	// Autosave debounce
	@State private var saveTask: Task<Void, Error>?
	@State private var isReverting = false

	// Delete confirmation
	@State private var showingDeleteConfirm = false

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(key: "favorite", ascending: false)],
		animation: .default
	) private var nodes: FetchedResults<NodeInfoEntity>

	init(channel: ChannelEntity, node: NodeInfoEntity?) {
		self.channel = channel
		self.node = node
		let key = channel.psk?.base64EncodedString() ?? ""
		var keySize = 16
		if key.isEmpty { keySize = 0 }
		else if key == "AQ==" { keySize = -1 }
		else if key.count == 4 { keySize = 1 }
		else if key.count == 24 { keySize = 16 }
		else if key.count == 32 { keySize = 24 }
		else if key.count == 44 { keySize = 32 }
		let precision = Double(channel.positionPrecision)
		let hasExactLocation = precision == 32 && key != "AQ=="
		let posEnabled = precision != 0
		_channelIndex = State(initialValue: channel.index)
		_channelName = State(initialValue: channel.name ?? "")
		_channelKeySize = State(initialValue: keySize)
		_channelKey = State(initialValue: key)
		_channelRole = State(initialValue: Int(channel.role))
		_uplink = State(initialValue: channel.uplinkEnabled)
		_downlink = State(initialValue: channel.downlinkEnabled)
		_positionPrecision = State(initialValue: precision)
		_preciseLocation = State(initialValue: hasExactLocation)
		_positionsEnabled = State(initialValue: posEnabled)
		// Snapshot original values so Revert can always restore to open-time state.
		// Using State(initialValue:) means SwiftUI only uses these on first creation;
		// subsequent re-renders (e.g. triggered by @ObservedObject after autosave)
		// do NOT re-run init's assignments for @State vars.
		_originalIndex = State(initialValue: channel.index)
		_originalName = State(initialValue: channel.name ?? "")
		_originalKeySize = State(initialValue: keySize)
		_originalKey = State(initialValue: key)
		_originalRole = State(initialValue: Int(channel.role))
		_originalUplink = State(initialValue: channel.uplinkEnabled)
		_originalDownlink = State(initialValue: channel.downlinkEnabled)
		_originalPositionPrecision = State(initialValue: precision)
		_originalPreciseLocation = State(initialValue: hasExactLocation)
		_originalPositionsEnabled = State(initialValue: posEnabled)
	}

	var body: some View {
		ChannelForm(
			title: "Edit Channel",
			embedded: true,
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
			supportedVersion: $supportedVersion,
			onDelete: { showingDeleteConfirm = true },
			isReverting: $isReverting
		)
		.onChange(of: channelName) { scheduleSave() }
		.onChange(of: channelKeySize) { scheduleSave() }
		.onChange(of: channelKey) { scheduleSave() }
		.onChange(of: channelRole) { scheduleSave() }
		.onChange(of: uplink) { scheduleSave() }
		.onChange(of: downlink) { scheduleSave() }
		.onChange(of: positionsEnabled) { scheduleSave() }
		.onChange(of: preciseLocation) { scheduleSave() }
		.onChange(of: positionPrecision) { scheduleSave() }
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					revert()
				} label: {
					Image(systemName: "arrow.uturn.backward")
				}
				.disabled(!hasChanges)
			}
		}
		.confirmationDialog(
			"Delete \(channelName.isEmpty ? "Channel \(channelIndex)" : channelName)?",
			isPresented: $showingDeleteConfirm,
			titleVisibility: .visible
		) {
			Button("Delete", role: .destructive) { deleteChannel() }
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("This cannot be undone.")
		}
		.onFirstAppear {
			supportedVersion = accessoryManager.checkIsVersionSupported(forVersion: minimumVersion)
		}
	}

	// MARK: - Autosave

	private func scheduleSave() {
		guard accessoryManager.isConnected, !isReverting else { return }
		saveTask?.cancel()
		saveTask = Task {
			try await Task.sleep(nanoseconds: 500_000_000)
			await MainActor.run { saveToDevice() }
		}
	}

	private func saveToDevice() {
		guard let currentNode = node else { return }
		var ch = Channel()
		ch.index = channelIndex
		ch.role = ChannelRoles(rawValue: channelRole)?.protoEnumValue() ?? .secondary
		ch.settings.name = channelName
		ch.settings.psk = Data(base64Encoded: channelKey) ?? Data()
		ch.settings.uplinkEnabled = uplink
		ch.settings.downlinkEnabled = downlink
		ch.settings.moduleSettings.positionPrecision = UInt32(positionPrecision)
		channel.role = Int32(channelRole)
		channel.index = channelIndex
		channel.name = channelName
		channel.psk = Data(base64Encoded: channelKey) ?? Data()
		channel.uplinkEnabled = uplink
		channel.downlinkEnabled = downlink
		channel.positionPrecision = Int32(positionPrecision)
		guard let mutableChannels = node?.myInfo?.channels?.mutableCopy() as? NSMutableOrderedSet else { return }
		if mutableChannels.contains(channel) {
			let replaceChannel = mutableChannels.first(where: { channel.psk == ($0 as AnyObject).psk && channel.name == ($0 as AnyObject).name })
			mutableChannels.replaceObject(at: mutableChannels.index(of: replaceChannel as Any), with: channel)
		} else {
			mutableChannels.add(channel)
		}
		node?.myInfo?.channels = mutableChannels.copy() as? NSOrderedSet
		context.refresh(channel, mergeChanges: true)
		do {
			try context.save()
			Logger.data.info("💾 Autosaved Channel: \(ch.settings.name, privacy: .public)")
		} catch {
			context.rollback()
			Logger.data.error("Unresolved Core Data error autosaving channel: \(error as NSError, privacy: .public)")
		}
		Task {
			_ = try await accessoryManager.saveChannel(channel: ch, fromUser: currentNode.user!, toUser: currentNode.user!)
			accessoryManager.mqttManager.connectFromConfigSettings(node: currentNode)
		}
	}

	// MARK: - Revert

	private func revert() {
		isReverting = true
		saveTask?.cancel()
		channelIndex = originalIndex
		channelName = originalName
		channelKeySize = originalKeySize
		channelKey = originalKey
		channelRole = originalRole
		uplink = originalUplink
		downlink = originalDownlink
		positionPrecision = originalPositionPrecision
		preciseLocation = originalPreciseLocation
		positionsEnabled = originalPositionsEnabled
		// Persist reverted values to the entity so navigating away shows the correct state.
		// @State storage is updated synchronously, so saveToDevice() reads the reverted values.
		saveToDevice()
		hasChanges = false
		// Reset flag after all onChange callbacks have fired on the next run-loop turn
		Task { @MainActor in
			try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s — enough for all onChange to drain
			isReverting = false
		}
	}

	// MARK: - Delete

	private func deleteChannel() {
		saveTask?.cancel()
		var ch = Channel()
		ch.index = channelIndex
		ch.role = .disabled
		ch.settings.name = channelName
		for object in channel.allPrivateMessages { context.delete(object) }
		for n in nodes where n.channel == ch.index { context.delete(n) }
		context.delete(channel)
		do {
			try context.save()
			Logger.data.info("💾 Deleted Channel: \(ch.settings.name, privacy: .public)")
		} catch {
			context.rollback()
			Logger.data.error("Unresolved Core Data error deleting channel: \(error as NSError, privacy: .public)")
			// Still dismiss — the context rolled back but we don't want the user stuck here
		}
		// Dismiss immediately; radio sync happens in background independently
		dismiss()
		guard let currentNode = node else { return }
		Task {
			try? await accessoryManager.saveChannel(channel: ch, fromUser: currentNode.user!, toUser: currentNode.user!)
			accessoryManager.mqttManager.connectFromConfigSettings(node: currentNode)
		}
	}
}

func firstMissingChannelIndex(_ indexes: [Int]) -> Int {
	let smallestIndex = 1
	if indexes.isEmpty { return smallestIndex }
	if smallestIndex <= indexes.count {
		for element in smallestIndex...indexes.count where !indexes.contains(element) {
			return element
		}
	}
	return indexes.count + 1
}

enum PositionPrecision: Int, CaseIterable, Identifiable {

	case two = 2
	case three = 3
	case four = 4
	case five = 5
	case six = 6
	case seven = 7
	case eight = 8
	case nine = 9
	case ten = 10
	case eleven = 11
	case twelve = 12
	case thirteen = 13
	case fourteen = 14
	case fifteen = 15
	case sixteen = 16
	case seventeen = 17
	case eightteen = 18
	case nineteen = 19
	case twenty = 20
	case twentyone = 21
	case twentytwo = 22
	case twentythree = 23
	case twentyfour = 24

	var id: Int { self.rawValue }

	var precisionMeters: Double {
		switch self {
		case .two:
			return 5976446.981252
		case .three:
			return 2988223.4850600003
		case .four:
			return 1494111.7369640006
		case .five:
			return 747055.8629159998
		case .six:
			return 373527.9258920002
		case .seven:
			return 186763.95738000044
		case .eight:
			return 93381.97312400135
		case .nine:
			return 46690.98099600022
		case .ten:
			return 23345.48493200123
		case .eleven:
			return 11672.736900000944
		case .twelve:
			return 5836.362884000802
		case .thirteen:
			return 2918.1758760007315
		case .fourteen:
			return 1459.0823719999053
		case .fifteen:
			return 729.5356200010741
		case .sixteen:
			return 364.7622440000765
		case .seventeen:
			return 182.37555600115968
		case .eightteen:
			return 91.1822120001193
		case .nineteen:
			return 45.58554000039009
		case .twenty:
			return 22.787204001316468
		case .twentyone:
			return 11.388036000988677
		case .twentytwo:
			return 5.688452000824781
		case .twentythree:
			return 2.8386600007428338
		case .twentyfour:
			return 1.413763999910884
		}
	}

	var description: String {
		let distanceFormatter = MKDistanceFormatter()
		return String.localizedStringWithFormat("Within %@".localized, String(distanceFormatter.string(fromDistance: precisionMeters)))
	}
}
