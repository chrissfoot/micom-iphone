/*
 * Copyright (c) 2010-2020 Belledonne Communications SARL.
 *
 * This file is part of linphone-iphone
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import SwiftUI
import linphonesw
import AVFAudio
import Combine

// swiftlint:disable type_body_length
class CallViewModel: ObservableObject {
	
	var coreContext = CoreContext.shared
	var telecomManager = TelecomManager.shared
	
	@Published var displayName: String = ""
	@Published var direction: Call.Dir = .Outgoing
	@Published var remoteAddressString: String = ""
	@Published var remoteAddress: Address?
	@Published var avatarModel: ContactAvatarModel?
	@Published var micMutted: Bool = false
	@Published var isRecording: Bool = false
	@Published var isRemoteRecording: Bool = false
	@Published var isPaused: Bool = false
	@Published var timeElapsed: Int = 0
	@Published var zrtpPopupDisplayed: Bool = false
	@Published var upperCaseAuthTokenToRead = ""
	@Published var upperCaseAuthTokenToListen = ""
	@Published var isMediaEncrypted: Bool = false
	@Published var isZrtpPq: Bool = false
	@Published var isRemoteDeviceTrusted: Bool = false
	@Published var selectedCall: Call?
	@Published var isTransferInsteadCall: Bool = false
	@Published var isOneOneCall: Bool = false
	@Published var isConference: Bool = false
	@Published var videoDisplayed: Bool = false
	@Published var participantList: [ParticipantModel] = []
	@Published var activeSpeakerParticipant: ParticipantModel?
	@Published var activeSpeakerName: String = ""
	@Published var myParticipantModel: ParticipantModel?
	@Published var callMediaEncryptionModel = CallMediaEncryptionModel()

	private var mConferenceSuscriptions = Set<AnyCancellable?>()
	
	var calls: [Call] = []
	
	let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
	
	var currentCall: Call?
	
	private var callSuscriptions = Set<AnyCancellable?>()
	
	init() {
		do {
			try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: .allowBluetooth)
		} catch _ {
			
		}
	}
	
	func enableAVAudioSession() {
		do {
			try AVAudioSession.sharedInstance().setActive(true)
		} catch _ {
			
		}
	}
	
	func disableAVAudioSession() {
		do {
			try AVAudioSession.sharedInstance().setActive(false)
		} catch _ {
			
		}
	}
	
	func resetCallView() {
		coreContext.doOnCoreQueue { core in
			if core.currentCall != nil && core.currentCall!.remoteAddress != nil {
				self.currentCall = core.currentCall
				
				var videoDisplayedTmp = false
				do {
					let params = try core.createCallParams(call: self.currentCall)
					videoDisplayedTmp = params.videoDirection == MediaDirection.SendRecv || params.videoDirection == MediaDirection.SendOnly
				} catch {
					
				}
				
				var isOneOneCallTmp = false
				if self.currentCall?.remoteAddress != nil {
					let conf = self.currentCall!.conference
					let confInfo = core.findConferenceInformationFromUri(uri: self.currentCall!.remoteAddress!)
					if conf == nil && confInfo == nil {
						isOneOneCallTmp = true
					}
				}
				
				var isMediaEncryptedTmp = false
				var isZrtpPqTmp = false
				if self.currentCall != nil && self.currentCall!.currentParams != nil {
					if self.currentCall!.currentParams!.mediaEncryption == .ZRTP ||
						self.currentCall!.currentParams!.mediaEncryption == .SRTP ||
						self.currentCall!.currentParams!.mediaEncryption == .DTLS {
						
						isMediaEncryptedTmp = true
						isZrtpPqTmp = self.currentCall!.currentParams!.mediaEncryption == .ZRTP
					}
				}
				
				let directionTmp = self.currentCall!.dir
				let remoteAddressStringTmp = String(self.currentCall!.remoteAddress!.asStringUriOnly().dropFirst(4))
				let remoteAddressTmp = self.currentCall!.remoteAddress!
				var displayNameTmp = ""
				if self.currentCall?.conference != nil {
					displayNameTmp = self.currentCall?.conference?.subject ?? ""
				} else if self.currentCall?.remoteAddress != nil {
					let friend = ContactsManager.shared.getFriendWithAddress(address: self.currentCall!.remoteAddress!)
					if friend != nil && friend!.address != nil && friend!.address!.displayName != nil {
						displayNameTmp = friend!.address!.displayName!
					} else {
						if self.currentCall!.remoteAddress!.displayName != nil {
							displayNameTmp = self.currentCall!.remoteAddress!.displayName!
						} else if self.currentCall!.remoteAddress!.username != nil {
							displayNameTmp = self.currentCall!.remoteAddress!.username!
						}
					}
				}
				
				let micMuttedTmp = self.currentCall!.microphoneMuted || !core.micEnabled
				let isRecordingTmp = self.currentCall!.params!.isRecording
				let isPausedTmp = self.isCallPaused()
				let timeElapsedTmp = self.currentCall?.duration ?? 0
				
				let authToken = self.currentCall!.authenticationToken
				let isDeviceTrusted = self.currentCall!.authenticationTokenVerified && authToken != nil
				let isRemoteDeviceTrustedTmp = self.telecomManager.callInProgress ? isDeviceTrusted : false
				
				if self.currentCall != nil {
					self.callMediaEncryptionModel.update(call: self.currentCall!)
				}
				
				DispatchQueue.main.async {
					self.direction = directionTmp
					self.remoteAddressString = remoteAddressStringTmp
					self.remoteAddress = remoteAddressTmp
					self.displayName = displayNameTmp
					
					//self.avatarModel = ???
					self.micMutted = micMuttedTmp
					self.isRecording = isRecordingTmp
					self.isPaused = isPausedTmp
					self.timeElapsed = timeElapsedTmp
					
					self.isRemoteDeviceTrusted = isRemoteDeviceTrustedTmp
					self.activeSpeakerParticipant = nil
					
					self.avatarModel = nil
					self.isRemoteRecording = false
					self.zrtpPopupDisplayed = false
					self.upperCaseAuthTokenToRead = ""
					self.upperCaseAuthTokenToListen = ""
					self.isConference = false
					self.participantList = []
					self.activeSpeakerParticipant = nil
					self.activeSpeakerName = ""
					self.myParticipantModel = nil
					
					self.videoDisplayed = videoDisplayedTmp
					self.isOneOneCall = isOneOneCallTmp
					self.isMediaEncrypted = isMediaEncryptedTmp
					self.isZrtpPq = isZrtpPqTmp
					
					self.getCallsList()
					
					if self.currentCall?.conference?.state == .Created {
						self.getConference()
					} else {
						self.waitingForCreatedStateConference()
					}
				}
				
				self.callSuscriptions.insert(self.currentCall!.publisher?.onEncryptionChanged?.postOnMainQueue {(cbVal: (call: Call, on: Bool, authenticationToken: String?)) in
					_ = self.updateEncryption()
					if self.currentCall != nil {
						self.callMediaEncryptionModel.update(call: self.currentCall!)
					}
				})
			}
		}
	}
	
	func getCallsList() {
		coreContext.doOnCoreQueue { core in
			DispatchQueue.main.async {
				self.calls = core.calls
			}
		}
	}
	
	func getConference() {
		coreContext.doOnCoreQueue { core in
			if self.currentCall?.conference != nil {
				let conf = self.currentCall!.conference!
				self.isConference = true
				
				let displayNameTmp = conf.subject ?? ""
				
				var myParticipantModelTmp: ParticipantModel? = nil
				if conf.me?.address != nil {
					myParticipantModelTmp = ParticipantModel(address: conf.me!.address!, isJoining: false, onPause: false, isMuted: false, isAdmin: conf.me!.isAdmin)
				} else if self.currentCall?.callLog?.localAddress != nil {
					myParticipantModelTmp = ParticipantModel(address: self.currentCall!.callLog!.localAddress!, isJoining: false, onPause: false, isMuted: false, isAdmin: conf.me!.isAdmin)
				}
				
				var activeSpeakerParticipantTmp: ParticipantModel? = nil
				if conf.activeSpeakerParticipantDevice?.address != nil {
					activeSpeakerParticipantTmp = ParticipantModel(
						address: conf.activeSpeakerParticipantDevice!.address!,
						isJoining: false,
						onPause: conf.activeSpeakerParticipantDevice!.state == .OnHold,
						isMuted: conf.activeSpeakerParticipantDevice!.isMuted
					)
				} else if conf.participantList.first?.address != nil && conf.participantList.first!.address!.clone()!.equal(address2: (conf.me?.address)!) {
					activeSpeakerParticipantTmp = ParticipantModel(
						address: conf.participantDeviceList.first!.address!,
						isJoining: false,
						onPause: conf.participantDeviceList.first!.state == .OnHold,
						isMuted: conf.participantDeviceList.first!.isMuted
					)
				} else if conf.participantList.last?.address != nil {
					activeSpeakerParticipantTmp = ParticipantModel(
						address: conf.participantDeviceList.last!.address!,
						isJoining: false,
						onPause: conf.participantDeviceList.last!.state == .OnHold,
						isMuted: conf.participantDeviceList.last!.isMuted
					)
				}
				
				var activeSpeakerNameTmp = ""
				if activeSpeakerParticipantTmp != nil {
					let friend = ContactsManager.shared.getFriendWithAddress(address: activeSpeakerParticipantTmp!.address)
					if friend != nil && friend!.address != nil && friend!.address!.displayName != nil {
						activeSpeakerNameTmp = friend!.address!.displayName!
					} else {
						if activeSpeakerParticipantTmp!.address.displayName != nil {
							activeSpeakerNameTmp = activeSpeakerParticipantTmp!.address.displayName!
						} else if activeSpeakerParticipantTmp!.address.username != nil {
							activeSpeakerNameTmp = activeSpeakerParticipantTmp!.address.username!
						}
					}
				}
				
				var participantListTmp: [ParticipantModel] = []
				conf.participantDeviceList.forEach({ participantDevice in
					if participantDevice.address != nil && !conf.isMe(uri: participantDevice.address!.clone()!) {
						if !conf.isMe(uri: participantDevice.address!.clone()!) {
							let isAdmin = conf.participantList.first(where: {$0.address!.equal(address2: participantDevice.address!.clone()!)})?.isAdmin
							participantListTmp.append(
								ParticipantModel(
									address: participantDevice.address!,
									isJoining: participantDevice.state == .Joining || participantDevice.state == .Alerting,
									onPause: participantDevice.state == .OnHold,
									isMuted: participantDevice.isMuted,
									isAdmin: isAdmin ?? false
								)
							)
						}
					}
				})
				
				DispatchQueue.main.async {
					self.displayName = displayNameTmp
					
					self.myParticipantModel = myParticipantModelTmp
					
					self.activeSpeakerParticipant = activeSpeakerParticipantTmp
					
					self.activeSpeakerName = activeSpeakerNameTmp
					
					self.participantList = participantListTmp
					
					self.addConferenceCallBacks()
				}
			} else if self.currentCall?.remoteContactAddress != nil {
				self.addConferenceCallBacks()
			}
		}
	}
	
	func waitingForCreatedStateConference() {
		self.mConferenceSuscriptions.insert(
			self.currentCall?.conference?.publisher?.onStateChanged?.postOnMainQueue {(cbValue: (conference: Conference, state: Conference.State)) in
				if cbValue.state == .Created {
					self.getConference()
				}
			}
		)
	}
	
	// swiftlint:disable:next cyclomatic_complexity
	func addConferenceCallBacks() {
		coreContext.doOnCoreQueue { core in
			self.mConferenceSuscriptions.insert(
				self.currentCall?.conference?.publisher?.onActiveSpeakerParticipantDevice?.postOnMainQueue {(cbValue: (conference: Conference, participantDevice: ParticipantDevice)) in
					if cbValue.participantDevice.address != nil {
						let activeSpeakerParticipantBis = self.activeSpeakerParticipant
						
						let activeSpeakerParticipantTmp = ParticipantModel(
							address: cbValue.participantDevice.address!,
							isJoining: false,
							onPause: cbValue.participantDevice.state == .OnHold,
							isMuted: cbValue.participantDevice.isMuted
						)
						
						var activeSpeakerNameTmp = ""
						let friend = ContactsManager.shared.getFriendWithAddress(address: activeSpeakerParticipantTmp.address)
						if friend != nil && friend!.address != nil && friend!.address!.displayName != nil {
							activeSpeakerNameTmp = friend!.address!.displayName!
						} else {
							if activeSpeakerParticipantTmp.address.displayName != nil {
								activeSpeakerNameTmp = activeSpeakerParticipantTmp.address.displayName!
							} else if activeSpeakerParticipantTmp.address.username != nil {
								activeSpeakerNameTmp = activeSpeakerParticipantTmp.address.username!
							}
						}
						
						var participantListTmp: [ParticipantModel] = []
						if (activeSpeakerParticipantBis != nil && !activeSpeakerParticipantBis!.address.equal(address2: activeSpeakerParticipantTmp.address))
								|| ( activeSpeakerParticipantBis == nil) {
							
							cbValue.conference.participantDeviceList.forEach({ participantDevice in
								if participantDevice.address != nil && !cbValue.conference.isMe(uri: participantDevice.address!.clone()!) {
									if !cbValue.conference.isMe(uri: participantDevice.address!.clone()!) {
										let isAdmin = cbValue.conference.participantList.first(where: {$0.address!.equal(address2: participantDevice.address!.clone()!)})?.isAdmin
										participantListTmp.append(
											ParticipantModel(
												address: participantDevice.address!,
												isJoining: participantDevice.state == .Joining || participantDevice.state == .Alerting,
												onPause: participantDevice.state == .OnHold,
												isMuted: participantDevice.isMuted,
												isAdmin: isAdmin ?? false
											)
										)
									}
								}
							})
						}
						
						DispatchQueue.main.async {
							self.activeSpeakerParticipant = activeSpeakerParticipantTmp
							self.activeSpeakerName = activeSpeakerNameTmp
							if (activeSpeakerParticipantBis != nil && !activeSpeakerParticipantBis!.address.equal(address2: activeSpeakerParticipantTmp.address))
								|| ( activeSpeakerParticipantBis == nil) {
								self.participantList = participantListTmp
							}
						}
					}
				}
			)
			
			self.mConferenceSuscriptions.insert(
				self.currentCall?.conference?.publisher?.onParticipantDeviceAdded?.postOnMainQueue {(cbValue: (conference: Conference, participantDevice: ParticipantDevice)) in
					if cbValue.participantDevice.address != nil {
						var participantListTmp: [ParticipantModel] = []
						cbValue.conference.participantDeviceList.forEach({ participantDevice in
							if participantDevice.address != nil && !cbValue.conference.isMe(uri: participantDevice.address!.clone()!) {
								if !cbValue.conference.isMe(uri: participantDevice.address!.clone()!) {
									let isAdmin = cbValue.conference.participantList.first(where: {$0.address!.equal(address2: participantDevice.address!.clone()!)})?.isAdmin
									participantListTmp.append(
										ParticipantModel(
											address: participantDevice.address!,
											isJoining: participantDevice.state == .Joining || participantDevice.state == .Alerting,
											onPause: participantDevice.state == .OnHold,
											isMuted: participantDevice.isMuted,
											isAdmin: isAdmin ?? false
										)
									)
								}
							}
						})
						
						var activeSpeakerParticipantTmp: ParticipantModel? = nil
						var activeSpeakerNameTmp = ""
						
						if self.activeSpeakerParticipant == nil {
							if cbValue.conference.activeSpeakerParticipantDevice?.address != nil {
								activeSpeakerParticipantTmp = ParticipantModel(
									address: cbValue.conference.activeSpeakerParticipantDevice!.address!,
									isJoining: false,
									onPause: cbValue.conference.activeSpeakerParticipantDevice!.state == .OnHold,
									isMuted: cbValue.conference.activeSpeakerParticipantDevice!.isMuted
								)
							} else if cbValue.conference.participantList.first?.address != nil && cbValue.conference.participantList.first!.address!.clone()!.equal(address2: (cbValue.conference.me?.address)!) {
								activeSpeakerParticipantTmp = ParticipantModel(
									address: cbValue.conference.participantDeviceList.first!.address!,
									isJoining: false,
									onPause: cbValue.conference.participantDeviceList.first!.state == .OnHold,
									isMuted: cbValue.conference.participantDeviceList.first!.isMuted
								)
							} else if cbValue.conference.participantList.last?.address != nil {
								activeSpeakerParticipantTmp = ParticipantModel(
									address: cbValue.conference.participantDeviceList.last!.address!,
									isJoining: false,
									onPause: cbValue.conference.participantDeviceList.last!.state == .OnHold,
									isMuted: cbValue.conference.participantDeviceList.last!.isMuted
								)
							}
							
							if activeSpeakerParticipantTmp != nil {
								let friend = ContactsManager.shared.getFriendWithAddress(address: activeSpeakerParticipantTmp!.address)
								if friend != nil && friend!.address != nil && friend!.address!.displayName != nil {
									activeSpeakerNameTmp = friend!.address!.displayName!
								} else {
									if activeSpeakerParticipantTmp!.address.displayName != nil {
										activeSpeakerNameTmp = activeSpeakerParticipantTmp!.address.displayName!
									} else if activeSpeakerParticipantTmp!.address.username != nil {
										activeSpeakerNameTmp = activeSpeakerParticipantTmp!.address.username!
									}
								}
							}
						}
						
						DispatchQueue.main.async {
							if self.activeSpeakerParticipant == nil {
								self.activeSpeakerParticipant = activeSpeakerParticipantTmp
								self.activeSpeakerName = activeSpeakerNameTmp
							}
							self.participantList = participantListTmp
						}
					}
				}
			)
			
			self.mConferenceSuscriptions.insert(
				self.currentCall?.conference?.publisher?.onParticipantDeviceRemoved?.postOnMainQueue {(cbValue: (conference: Conference, participantDevice: ParticipantDevice)) in
					if cbValue.participantDevice.address != nil {
						var participantListTmp: [ParticipantModel] = []
						cbValue.conference.participantDeviceList.forEach({ participantDevice in
							if participantDevice.address != nil && !cbValue.conference.isMe(uri: participantDevice.address!.clone()!) {
								if !cbValue.conference.isMe(uri: participantDevice.address!.clone()!) {
									let isAdmin = cbValue.conference.participantList.first(where: {$0.address!.equal(address2: participantDevice.address!.clone()!)})?.isAdmin
									participantListTmp.append(
										ParticipantModel(
											address: participantDevice.address!,
											isJoining: participantDevice.state == .Joining || participantDevice.state == .Alerting,
											onPause: participantDevice.state == .OnHold,
											isMuted: participantDevice.isMuted,
											isAdmin: isAdmin ?? false
										)
									)
								}
							}
						})
						
						let participantDeviceListCount = cbValue.conference.participantDeviceList.count
						
						DispatchQueue.main.async {
							self.participantList = participantListTmp
							
							if participantDeviceListCount == 1 {
								self.activeSpeakerParticipant = nil
							}
						}
					}
				}
			)
			
			self.mConferenceSuscriptions.insert(
				self.currentCall?.conference?.publisher?.onParticipantDeviceIsMuted?.postOnMainQueue {(cbValue: (conference: Conference, participantDevice: ParticipantDevice, isMuted: Bool)) in
					if self.activeSpeakerParticipant != nil && self.activeSpeakerParticipant!.address.equal(address2: cbValue.participantDevice.address!) {
						let isMutedTmp = cbValue.isMuted
						
						DispatchQueue.main.async {
							self.activeSpeakerParticipant!.isMuted = isMutedTmp
						}
					}
					self.participantList.forEach({ participantDevice in
						if participantDevice.address.equal(address2: cbValue.participantDevice.address!) {
							let isMutedTmp = cbValue.isMuted
							
							DispatchQueue.main.async {
								participantDevice.isMuted = isMutedTmp
							}
						}
					})
				}
			)
			
			self.mConferenceSuscriptions.insert(
				self.currentCall?.conference?.publisher?.onParticipantDeviceStateChanged?.postOnMainQueue {(cbValue: (conference: Conference, device: ParticipantDevice, state: ParticipantDevice.State)) in
					Log.info(
						"[CallViewModel] Participant device \(cbValue.device.address!.asStringUriOnly()) state changed \(cbValue.state)"
					)
					if self.activeSpeakerParticipant != nil && self.activeSpeakerParticipant!.address.equal(address2: cbValue.device.address!) {
						let activeSpeakerParticipantOnPauseTmp = cbValue.state == .OnHold
						let activeSpeakerParticipantIsJoiningTmp = cbValue.state == .Joining || cbValue.state == .Alerting
						DispatchQueue.main.async {
							self.activeSpeakerParticipant!.onPause = activeSpeakerParticipantOnPauseTmp
							self.activeSpeakerParticipant!.isJoining = activeSpeakerParticipantIsJoiningTmp
						}
					}
					self.participantList.forEach({ participantDevice in
						if participantDevice.address.equal(address2: cbValue.device.address!) {
							let participantDeviceOnPauseTmp = cbValue.state == .OnHold
							let participantDeviceIsJoiningTmp = cbValue.state == .Joining || cbValue.state == .Alerting
							DispatchQueue.main.async {
								participantDevice.onPause = participantDeviceOnPauseTmp
								participantDevice.isJoining = participantDeviceIsJoiningTmp
							}
						}
					})
				}
			)
			
			self.mConferenceSuscriptions.insert(
				self.currentCall?.conference?.publisher?.onParticipantAdminStatusChanged?.postOnMainQueue {(cbValue: (conference: Conference, participant: Participant)) in
					let isAdmin = cbValue.participant.isAdmin
					if self.myParticipantModel != nil && self.myParticipantModel!.address.clone()!.equal(address2: cbValue.participant.address!) {
						DispatchQueue.main.async {
							self.myParticipantModel!.isAdmin = isAdmin
						}
					}
					self.participantList.forEach({ participantDevice in
						if participantDevice.address.clone()!.equal(address2: cbValue.participant.address!) {
							DispatchQueue.main.async {
								participantDevice.isAdmin = isAdmin
							}
						}
					})
				}
			)
			
			self.mConferenceSuscriptions.insert(
				self.currentCall?.conference?.publisher?.onParticipantDeviceIsSpeakingChanged?.postOnMainQueue {(cbValue: (conference: Conference, participantDevice: ParticipantDevice, isSpeaking: Bool)) in
					let isSpeaking = cbValue.participantDevice.isSpeaking
					if self.myParticipantModel != nil && self.myParticipantModel!.address.clone()!.equal(address2: cbValue.participantDevice.address!) {
						DispatchQueue.main.async {
							self.myParticipantModel!.isSpeaking = isSpeaking
						}
					}
					self.participantList.forEach({ participantDeviceList in
						if participantDeviceList.address.clone()!.equal(address2: cbValue.participantDevice.address!) {
							DispatchQueue.main.async {
								participantDeviceList.isSpeaking = isSpeaking
							}
						}
					})
				}
			)
		}
	}
	
	func terminateCall() {
		coreContext.doOnCoreQueue { core in
			if self.currentCall != nil {
				self.telecomManager.terminateCall(call: self.currentCall!)
			}
			
			if core.callsNb == 0 {
				DispatchQueue.main.async {
					self.timer.upstream.connect().cancel()
				}
			}
		}
	}
	
	func acceptCall() {
		withAnimation {
			telecomManager.outgoingCallStarted = false
			telecomManager.callInProgress = true
			telecomManager.callDisplayed = true
			telecomManager.callStarted = true
		}
		
		coreContext.doOnCoreQueue { core in
			if self.currentCall != nil {
				self.telecomManager.acceptCall(core: core, call: self.currentCall!, hasVideo: false)
			}
		}
		
		timer.upstream.connect().cancel()
	}
	
	func toggleMuteMicrophone() {
		coreContext.doOnCoreQueue { core in
			if self.currentCall != nil {
				if !core.micEnabled && !self.currentCall!.microphoneMuted {
					core.micEnabled = true
				} else {
					self.currentCall!.microphoneMuted = !self.currentCall!.microphoneMuted
				}
				
				let micMuttedTmp = self.currentCall!.microphoneMuted || !core.micEnabled
				DispatchQueue.main.async {
					self.micMutted = micMuttedTmp
				}
				
				Log.info(
					"[CallViewModel] Microphone mute switch \(self.micMutted)"
				)
			}
		}
	}
	
	func displayMyVideo() {
		coreContext.doOnCoreQueue { core in
			if self.currentCall != nil {
				do {
					let params = try core.createCallParams(call: self.currentCall)
					
					params.videoEnabled = true
					
					if params.videoEnabled {
						if params.videoDirection == .SendRecv {
							params.videoDirection = .RecvOnly
						} else if params.videoDirection == .RecvOnly {
							params.videoDirection = .SendRecv
						} else if params.videoDirection == .SendOnly {
							params.videoDirection = .Inactive
						} else if params.videoDirection == .Inactive {
							params.videoDirection = .SendOnly
						}
					}
					
					try self.currentCall!.update(params: params)
					
					let video = params.videoDirection == .SendRecv || params.videoDirection == .SendOnly
					
					DispatchQueue.main.asyncAfter(deadline: .now() + (video ? 1 : 0)) {
						if video {
							self.videoDisplayed = false
						}
						self.videoDisplayed = video
					}
				} catch {
					
				}
			}
		}
	}
	
	func toggleVideoMode(isAudioOnlyMode: Bool) {
		coreContext.doOnCoreQueue { core in
			if self.currentCall != nil {
				do {
					let params = try core.createCallParams(call: self.currentCall)
					
					params.videoEnabled = !isAudioOnlyMode
					
					try self.currentCall!.update(params: params)
				} catch {
					
				}
			}
		}
	}
	
	func switchCamera() {
		coreContext.doOnCoreQueue { core in
			let currentDevice = core.videoDevice
			Log.info("[CallViewModel] Current camera device is \(currentDevice)")
			
			core.videoDevicesList.forEach { camera in
				if camera != currentDevice && camera != "StaticImage: Static picture" {
					Log.info("[CallViewModel] New camera device will be \(camera)")
					do {
						try core.setVideodevice(newValue: camera)
					} catch _ {
						
					}
				}
			}
		}
	}
	
	func toggleRecording() {
		coreContext.doOnCoreQueue { _ in
			if self.currentCall != nil && self.currentCall!.params != nil {
				if self.currentCall!.params!.isRecording {
					Log.info("[CallViewModel] Stopping call recording")
					self.currentCall!.stopRecording()
				} else {
					Log.info("[CallViewModel] Starting call recording \(self.currentCall!.params!.isRecording)")
					self.currentCall!.startRecording()
				}
				
				let isRecordingTmp = self.currentCall!.params!.isRecording
				DispatchQueue.main.async {
					self.isRecording = isRecordingTmp
				}
			}
		}
	}
	
	func togglePause() {
		coreContext.doOnCoreQueue { _ in
			if self.currentCall != nil && self.currentCall!.remoteAddress != nil {
				do {
					if self.isCallPaused() {
						Log.info("[CallViewModel] Resuming call \(self.currentCall!.remoteAddress!.asStringUriOnly())")
						try self.currentCall!.resume()
						
						DispatchQueue.main.async {
							self.isPaused = false
						}
					} else {
						Log.info("[CallViewModel] Pausing call \(self.currentCall!.remoteAddress!.asStringUriOnly())")
						try self.currentCall!.pause()
						
						DispatchQueue.main.async {
							self.isPaused = true
						}
					}
				} catch _ {
					
				}
			}
		}
	}
	
	func isCallPaused() -> Bool {
		var result = false
		if self.currentCall != nil {
			switch self.currentCall!.state {
			case Call.State.Paused, Call.State.Pausing:
				result = true
			default:
				result = false
			}
		}
		return result
	}
	
	func counterToMinutes() -> String {
		let currentTime = timeElapsed
		let seconds = currentTime % 60
		let minutes = String(format: "%02d", Int(currentTime / 60))
		let hours = String(format: "%02d", Int(currentTime / 3600))
		
		if Int(currentTime / 3600) > 0 {
			return "\(hours):\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
		} else {
			return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
		}
	}
	
	func isHeadPhoneAvailable() -> Bool {
		guard let availableInputs = AVAudioSession.sharedInstance().availableInputs else {return false}
		for inputDevice in availableInputs {
			if inputDevice.portType == .headsetMic  || inputDevice.portType == .headphones {
				return true
			}
		}
		return false
	}
	
	func orientationUpdate(orientation: UIDeviceOrientation) {
		coreContext.doOnCoreQueue { core in
			let oldLinphoneOrientation = core.deviceRotation
			var newRotation = 0
			switch orientation {
			case .portrait:
				newRotation = 0
			case .portraitUpsideDown:
				newRotation = 180
			case .landscapeRight:
				newRotation = 90
			case .landscapeLeft:
				newRotation = 270
			default:
				newRotation = oldLinphoneOrientation
			}
			
			if oldLinphoneOrientation != newRotation {
				core.deviceRotation = newRotation
			}
		}
	}
	
	func lettersClicked(letters: String) {
		let verified = letters == self.upperCaseAuthTokenToListen
		Log.info(
			"[ZRTPPopup] User clicked on \(verified ? "right" : "wrong") letters"
		)
		
		if verified {
			coreContext.doOnCoreQueue { core in
				if core.currentCall != nil {
					core.currentCall!.authenticationTokenVerified = verified
				}
			}
		}
	}
	
	private func updateEncryption() -> Bool {
		if currentCall != nil && currentCall!.currentParams != nil {
			switch currentCall!.currentParams!.mediaEncryption {
			case MediaEncryption.ZRTP:
				let authToken = currentCall!.authenticationToken
				let isDeviceTrusted = currentCall!.authenticationTokenVerified && authToken != nil
				
				Log.info(
					"[CallViewModel] Current call media encryption is ZRTP, auth token is \(isDeviceTrusted ? "trusted" : "not trusted yet")"
				)
				
				isRemoteDeviceTrusted = isDeviceTrusted
				
				if isDeviceTrusted {
					ToastViewModel.shared.toastMessage = "Info_call_securised"
					ToastViewModel.shared.displayToast = true
				}
				
				/*
				 let securityLevel = isDeviceTrusted ? SecurityLevel.Safe : SecurityLevel.Encrypted
				 let avatarModel = contact
				 if (avatarModel != nil) {
				 avatarModel.trust.postValue(securityLevel)
				 contact.postValue(avatarModel!!)
				 } else {
				 Log.error("$TAG No avatar model found!")
				 }
				 */
				
				isMediaEncrypted = true
				// When Post Quantum is available, ZRTP is Post Quantum
				isZrtpPq = Core.getPostQuantumAvailable
				
				if !isDeviceTrusted && authToken != nil && !authToken!.isEmpty {
					Log.info("[CallViewModel] Showing ZRTP SAS confirmation dialog")
					showZrtpSasDialog(authToken: authToken!)
				}
				
				return isDeviceTrusted
			case MediaEncryption.SRTP, MediaEncryption.DTLS:
				isMediaEncrypted = true
				isZrtpPq = false
				return false
			default:
				isMediaEncrypted = false
				isZrtpPq = false
				return false
			}
		}
		return false
	}
	
	func showZrtpSasDialogIfPossible() {
		if currentCall != nil && currentCall!.currentParams != nil && currentCall!.currentParams!.mediaEncryption == MediaEncryption.ZRTP {
			let authToken = currentCall!.authenticationToken
			let isDeviceTrusted = currentCall!.authenticationTokenVerified && authToken != nil
			Log.info(
				"[CallViewModel] Current call media encryption is ZRTP, auth token is \(isDeviceTrusted ? "trusted" : "not trusted yet")"
			)
			if (authToken != nil && !authToken!.isEmpty) {
				showZrtpSasDialog(authToken: authToken!)
			}
		}
	}
	
	private func showZrtpSasDialog(authToken: String) {
		if self.currentCall != nil {
			let upperCaseAuthToken = authToken.localizedUppercase
			
			let mySubstringPrefix = upperCaseAuthToken.prefix(2)
			
			let mySubstringSuffix = upperCaseAuthToken.suffix(2)
			
			switch self.currentCall!.dir {
			case Call.Dir.Incoming:
				self.upperCaseAuthTokenToRead = String(mySubstringPrefix)
				self.upperCaseAuthTokenToListen = String(mySubstringSuffix)
			default:
				self.upperCaseAuthTokenToRead = String(mySubstringSuffix)
				self.upperCaseAuthTokenToListen = String(mySubstringPrefix)
			}
			
			self.zrtpPopupDisplayed = true
		}
	}
	
	func transferClicked() {
		coreContext.doOnCoreQueue { core in
			var callToTransferTo = core.calls.last { call in
				call.state == Call.State.Paused && call.callLog?.callId != self.currentCall?.callLog?.callId
			}
			
			if (callToTransferTo == nil) {
				Log.error(
					"[CallViewModel] Couldn't find a call in Paused state to transfer current call to"
				)
			} else {
				if self.currentCall != nil && self.currentCall!.remoteAddress != nil && callToTransferTo!.remoteAddress != nil {
					Log.info(
						"[CallViewModel] Doing an attended transfer between currently displayed call \(self.currentCall!.remoteAddress!.asStringUriOnly()) "
						+ "and paused call \(callToTransferTo!.remoteAddress!.asStringUriOnly())"
					)
					
					do {
						try callToTransferTo!.transferToAnother(dest: self.currentCall!)
						Log.info("[CallViewModel] Attended transfer is successful")
					} catch _ {
						ToastViewModel.shared.toastMessage = "Failed_toast_call_transfer_failed"
						ToastViewModel.shared.displayToast = true
						
						Log.error("[CallViewModel] Failed to make attended transfer!")
					}
				}
			}
		}
	}
	
	func blindTransferCallTo(toAddress: Address) {
		if self.currentCall != nil && self.currentCall!.remoteAddress != nil {
			Log.info(
				"[CallViewModel] Call \(self.currentCall!.remoteAddress!.asStringUriOnly()) is being blindly transferred to \(toAddress.asStringUriOnly())"
			)
			
			do {
				try self.currentCall!.transferTo(referTo: toAddress)
				Log.info("[CallViewModel] Blind call transfer is successful")
			} catch _ {
				ToastViewModel.shared.toastMessage = "Failed_toast_call_transfer_failed"
				ToastViewModel.shared.displayToast = true
				
				Log.error("[CallViewModel] Failed to make blind call transfer!")
			}
		}
	}
	
	func toggleAdminParticipant(index: Int) {
		coreContext.doOnCoreQueue { core in
			self.currentCall?.conference?.participantList.forEach({ participant in
				if participant.address != nil && self.participantList[index].address.clone() != nil && participant.address!.equal(address2: self.participantList[index].address.clone()!) {
					self.currentCall?.conference?.setParticipantAdminStatus(participant: participant, isAdmin: !participant.isAdmin)
				}
			})
		}
	}
	
	func removeParticipant(index: Int) {
		coreContext.doOnCoreQueue { core in
			self.currentCall?.conference?.participantList.forEach({ participant in
				if participant.address != nil && self.participantList[index].address.clone() != nil && participant.address!.equal(address2: self.participantList[index].address.clone()!) {
					do {
						try self.currentCall?.conference?.removeParticipant(participant: participant)
					} catch {
						
					}
				}
			})
		}
	}
}
// swiftlint:enable type_body_length
