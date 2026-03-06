//
//  ChannelForm.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 3/17/24.
//

import SwiftUI
import MapKit

struct ChannelForm: View {

	var title: String = "Channel"
	/// When true, renders the Form directly without its own NavigationStack.
	/// Use this when pushing via NavigationLink inside an existing NavigationStack.
	var embedded: Bool = false
	@Binding var channelIndex: Int32
	@Binding var channelName: String
	@Binding var channelKeySize: Int
	@Binding var channelKey: String
	@Binding var channelRole: Int
	@Binding var uplink: Bool
	@Binding var downlink: Bool
	@Binding var positionPrecision: Double
	@Binding var preciseLocation: Bool
	@Binding var positionsEnabled: Bool
	@Binding var hasChanges: Bool
	@Binding var hasValidKey: Bool
	@Binding var supportedVersion: Bool
	/// When non-nil, a destructive "Delete Channel" section is shown at the bottom.
	var onDelete: (() -> Void)? = nil
	/// Set to true during a revert operation to suppress side-effect onChange handlers.
	var isReverting: Binding<Bool> = .constant(false)

	var body: some View {
		if embedded {
			formContent
		} else {
			NavigationStack { formContent }
		}
	}

	@ViewBuilder
	private var formContent: some View {
		Form {
			Section(header: Text("Channel Details")) {
				HStack {
					Text("Name")
					Spacer()
					TextField(
						"Channel Name",
						text: $channelName
					)
					.disableAutocorrection(true)
					.keyboardType(.alphabet)
					.foregroundColor(Color.gray)
					.onChange(of: channelName) {
						channelName = channelName.replacing(" ", with: "")
						var totalBytes = channelName.utf8.count
						// Only mess with the value if it is too big
						while totalBytes > 11 {
							channelName = String(channelName.dropLast())
							totalBytes = channelName.utf8.count
						}
						guard !isReverting.wrappedValue else { return }
						hasChanges = true
					}
				}
				HStack {
					Picker("Key Size", selection: $channelKeySize) {
						Text("Empty").tag(0)
						Text("Default").tag(-1)
						Text("1 byte").tag(1)
						Text("128 bit").tag(16)
						Text("256 bit").tag(32)
					}
					.pickerStyle(DefaultPickerStyle())
					Spacer()
					Button {
						if channelKeySize == -1 {
							channelKey = "AQ=="
						} else {
							let key = generateChannelKey(size: channelKeySize)
							channelKey = key
						}
					} label: {
						Image(systemName: "lock.rotation")
							.font(.title)
					}
					.buttonStyle(.bordered)
					.buttonBorderShape(.capsule)
					.controlSize(.small)
				}
				HStack(alignment: .center) {
					Text("Key")
					Spacer()
					TextField(
						"Key",
						text: $channelKey,
						axis: .vertical
					)
					.padding(6)
					.disableAutocorrection(true)
					.keyboardType(.alphabet)
					.foregroundColor(Color.gray)
					.textSelection(.enabled)
					.background(
						RoundedRectangle(cornerRadius: 10.0)
							.stroke(
								hasValidKey ?
								Color.clear :
									Color.red
								, lineWidth: 2.0)

					)
					.onChange(of: channelKey) {
						let tempKey = Data(base64Encoded: channelKey) ?? Data()
						if tempKey.count == channelKeySize || channelKeySize == -1 {
							hasValidKey = true
						} else {
							hasValidKey = false
						}
						guard !isReverting.wrappedValue else { return }
						hasChanges = true
					}
					.disabled(channelKeySize <= 0)
				}
				HStack {
					if channelRole == 1 {
						Picker("Channel Role", selection: $channelRole) {
							Text("Primary").tag(1)
						}
						.pickerStyle(.automatic)
						.disabled(true)
					} else {
						Text("Channel Role")
						Spacer()
						Picker("Channel Role", selection: $channelRole) {
							Text("Disabled").tag(0)
							Text("Secondary").tag(2)
						}
						.pickerStyle(.segmented)
					}
				}
			}

			Section(header: Text("Position")) {
				VStack(alignment: .leading) {
					Toggle(isOn: $positionsEnabled) {
						Label(channelRole == 1 ? "Positions Enabled" : "Allow Position Requests", systemImage: positionsEnabled ? "mappin" : "mappin.slash")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.disabled(!supportedVersion)
				}

				if positionsEnabled {
					if (channelKey != "AQ==" && channelKeySize > 1)  && channelRole > 0 {
						VStack(alignment: .leading) {
							Toggle(isOn: $preciseLocation) {
								Label("Precise Location", systemImage: "scope")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.disabled(!supportedVersion)
							.listRowSeparator(.visible)
							.onChange(of: preciseLocation) { _, pl in
								if pl == false {
									positionPrecision = 15
								}
							}
						}
					}
					if !preciseLocation {
						VStack(alignment: .leading) {
							Label("Approximate Location", systemImage: "location.slash.circle.fill")

							Slider(value: $positionPrecision, in: 12...15, step: 1) {
							} minimumValueLabel: {
								Image(systemName: "plus")
							} maximumValueLabel: {
								Image(systemName: "minus")
							}
							Text(PositionPrecision(rawValue: Int(positionPrecision))?.description ?? "")
								.foregroundColor(.gray)
								.font(.callout)
						}
					}
				}
			}
			Section(header: Text("MQTT")) {
				Toggle(isOn: $uplink) {
					Label("Uplink Enabled", systemImage: "arrowshape.up")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))
				.listRowSeparator(.visible)

				Toggle(isOn: $downlink) {
					Label("Downlink Enabled", systemImage: "arrowshape.down")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))
			}
			if let onDelete {
				Section {
					Button(role: .destructive, action: onDelete) {
						Label("Delete Channel", systemImage: "trash")
							.frame(maxWidth: .infinity)
					}
					.disabled(channelRole == 1)
				}
			}
		}
		.safeAreaInset(edge: .bottom) { Color.clear.frame(height: 44) }
		.onChange(of: channelName) {
			guard !isReverting.wrappedValue else { return }
			hasChanges = true
		}
		.onChange(of: channelKeySize) {
			guard !isReverting.wrappedValue else { return }
			if channelKeySize == -1 {
				channelKey = "AQ=="
			} else {
				let key = generateChannelKey(size: channelKeySize)
				channelKey = key
			}
			hasChanges = true
		}
		.onChange(of: channelKey) {
			guard !isReverting.wrappedValue else { return }
			hasChanges = true
		}
		.onChange(of: channelKeySize) {
			guard !isReverting.wrappedValue else { return }
			if channelKeySize == -1 {
				if channelRole == 0 {
					preciseLocation = false
				}
				channelKey = "AQ=="
			}
		}
		.onChange(of: channelRole) {
			guard !isReverting.wrappedValue else { return }
			hasChanges = true
		}
		.onChange(of: preciseLocation) { _, loc in
			guard !isReverting.wrappedValue else { return }
			if loc == true {
				if channelKey == "AQ==" || channelKeySize <= 1 {
					preciseLocation = false
				} else {
					positionPrecision = 32
				}
			} else {
				positionPrecision = 14
			}
			hasChanges = true
		}
		.onChange(of: positionPrecision) {
			guard !isReverting.wrappedValue else { return }
			hasChanges = true
		}
		.onChange(of: positionsEnabled) { _, pe in
			guard !isReverting.wrappedValue else { return }
			if pe {
				if positionPrecision == 0 {
					positionPrecision = 15
				}
			} else {
				positionPrecision = 0
			}
			hasChanges = true
		}
		.onChange(of: uplink) {
			guard !isReverting.wrappedValue else { return }
			hasChanges = true
		}
		.onChange(of: downlink) {
			guard !isReverting.wrappedValue else { return }
			hasChanges = true
		}
		.onFirstAppear {
			let tempKey = Data(base64Encoded: channelKey) ?? Data()
			if tempKey.count == channelKeySize || channelKeySize == -1 {
				hasValidKey = true
			} else {
				hasValidKey = false
			}
		}
		.navigationTitle(title)
	}
}
