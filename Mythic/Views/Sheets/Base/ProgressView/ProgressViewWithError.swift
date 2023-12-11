//
//  ProgressViewWithError.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI

struct ProgressViewSheetWithError: View {
    @Binding var isError: Bool
    @Binding var isPresented: Bool

    var body: some View {
        if !isError {
            ProgressViewSheet(isPresented: $isPresented)
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.large)
                .padding()
                .fixedSize()
        }
    }
}
