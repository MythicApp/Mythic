//
//  MainEvo.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/29/24.
//

import SwiftUI

struct MainViewEvo: View {
    @StateObject private var networkMonitor: NetworkMonitor = .init()
    @State private var isSidebarShown: Bool = true
    
    var body: some View {
        HStack {
            if isSidebarShown {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background)
                    .frame(width: isSidebarShown ? 136 : 0)
                    .overlay(alignment: .top) {
                        Text("z")
                    }
                    .safeAreaPadding(.top, 32)
            }
            
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .overlay {
                    HomeView()
                        .environmentObject(networkMonitor)
                }
                
        }
        .padding(10)
        .navigationTitle("")
        .safeAreaPadding(.top, isSidebarShown ? 0 : 32)
        .ignoresSafeArea()
        .background(WindowBlurView().ignoresSafeArea())
        .frame(minWidth: 750, minHeight: 390)
        
        .onAppear {
            for window in NSApp.windows {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
            }
        }
        
        .presentedWindowToolbarStyle(.expanded)
        
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("\(isSidebarShown ? "Hide" : "Show") Sidebar", systemImage: "sidebar.leading") {
                    withAnimation(.linear(duration: 0.2)) {
                        isSidebarShown.toggle()
                    }
                }
            }
            
            if !networkMonitor.isEpicAccessible {
                ToolbarItem(placement: .navigation) {
                    if networkMonitor.isCheckingEpicAccessibility {
                        Image(systemName: "network.slash")
                            .symbolEffect(.pulse)
                            .help("Mythic is checking the connection to Epic.")
                    } else if networkMonitor.isConnected {
                        Image(systemName: "wifi.exclamationmark")
                            .symbolEffect(.pulse)
                            .help("Mythic is connected to the internet, but cannot establish a connection to Epic.")
                    } else {
                        Image(systemName: "network.slash")
                            .help("Mythic is not connected to the internet.")
                    }
                }
            }
        }
        
    }
}

#Preview {
    MainViewEvo()
}
