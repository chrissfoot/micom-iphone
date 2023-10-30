/*
 * Copyright (c) 2010-2023 Belledonne Communications SARL.
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

import linphonesw

class EditContactViewModel: ObservableObject {
	
	@Published var selectedEditFriend: Friend?
	
	@Published var firstName: String = ""
	@Published var lastName: String = ""
	@Published var sipAddresses: [String] = []
	@Published var phoneNumbers: [String] = []
	@Published var company: String = ""
	@Published var jobTitle: String = ""
	@Published var removePopup: Bool = false
	
	init() {
		resetValues()
	}
	
	func resetValues() {
		firstName = (selectedEditFriend == nil ? "" : selectedEditFriend!.vcard?.givenName) ?? ""
		lastName = (selectedEditFriend == nil ? "" : selectedEditFriend!.vcard?.familyName) ?? ""
		sipAddresses = []
		phoneNumbers = []
		company = (selectedEditFriend == nil ? "" : selectedEditFriend!.organization) ?? ""
		jobTitle = (selectedEditFriend == nil ? "" : selectedEditFriend!.jobTitle) ?? ""
		
		if selectedEditFriend != nil {
			selectedEditFriend?.addresses.forEach({ address in
				sipAddresses.append(String(address.asStringUriOnly().dropFirst(4)))
			})
			
			selectedEditFriend?.phoneNumbers.forEach({ phoneNumber in
				phoneNumbers.append(phoneNumber)
			})
			
		}
		
		sipAddresses.append("")
		phoneNumbers.append("")
	}
}
