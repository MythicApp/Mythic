//
//  NotImplemented.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

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

func NotImplementedAlert(isPresented: Binding<Bool>, warning: String? = nil) -> Alert {
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
