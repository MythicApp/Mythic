//
//  NotImplemented.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import OSLog

struct NotImplementedView: View {
    var body: some View {
        VStack {
            Image(systemName: "calendar.badge.clock")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 35, height: 35)
                .font(.system(.caption, design: .rounded))
                .symbolEffect(.pulse)

            Text("Sorry, this isn't implemented yet!")
        }
        .padding()
    }
}

func notImplementedAlert(isPresented: Binding<Bool>, warning: String? = nil) -> Alert {
    return Alert(
        title: Text("Not implemented"),
        primaryButton: .default(Text("OK!")) {
            isPresented.wrappedValue = false
        },
        secondaryButton: .destructive(Text("Damn.")) {
            isPresented.wrappedValue = false
        }
    )
}

#Preview {
    NotImplementedView()
}
