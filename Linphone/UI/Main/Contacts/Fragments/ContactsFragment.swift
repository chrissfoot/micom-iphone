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

import SwiftUI

struct ContactsFragment: View {
	
	private var idiom: UIUserInterfaceIdiom { UIDevice.current.userInterfaceIdiom }
	
	@ObservedObject var contactViewModel: ContactViewModel
	
	@Binding var isShowDeletePopup: Bool
	
	@State private var showingSheet = false
	
	var body: some View {
		ZStack {
			if #available(iOS 16.0, *) {
				if idiom != .pad {
					ContactsInnerFragment(contactViewModel: contactViewModel, showingSheet: $showingSheet)
						.sheet(isPresented: $showingSheet) {
							ContactsListBottomSheet(contactViewModel: contactViewModel, isShowDeletePopup: $isShowDeletePopup, showingSheet: $showingSheet)
								.presentationDetents([.fraction(0.2)])
						}
				} else {
					ContactsInnerFragment(contactViewModel: contactViewModel, showingSheet: $showingSheet)
						.halfSheet(showSheet: $showingSheet) {
							ContactsListBottomSheet(contactViewModel: contactViewModel, isShowDeletePopup: $isShowDeletePopup, showingSheet: $showingSheet)
						} onDismiss: {}
				}
			} else {
				ContactsInnerFragment(contactViewModel: contactViewModel, showingSheet: $showingSheet)
					.halfSheet(showSheet: $showingSheet) {
						ContactsListBottomSheet(contactViewModel: contactViewModel, isShowDeletePopup: $isShowDeletePopup, showingSheet: $showingSheet)
					} onDismiss: {}
			}
		}
	}
}

#Preview {
	ContactsFragment(contactViewModel: ContactViewModel(), isShowDeletePopup: .constant(false))
}
