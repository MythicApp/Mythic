//
//  AppDelegate.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/23/24.
//

import Foundation
import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    public static let shared = AppDelegate()
    
    private let logger = AppLogger(category: AppDelegate.self)
    
    private let setupWindowController = SetupWindowController()
    private let mainWindowController = MainWindowController()
    
    /// Show the setup window
    private func showSetupWindow() {
        setupWindowController.show()
    }
    
    /// Hide the setup window
    private func hideSetupWindow() {
        setupWindowController.hide()
    }
    
    /// Show the main window
    private func showMainWindow() {
        mainWindowController.show()
    }
    
    /// Hide the main window
    private func hideMainWindow() {
        mainWindowController.hide()
    }
    
    /// Set the onboarding state
    public func setOnboardingState(inOnboarding: Bool) {
        if inOnboarding {
            logger.info("Showing onboarding window...")
            showSetupWindow()
            hideMainWindow()
        } else {
            logger.info("Showing main window...")
            hideSetupWindow()
            showMainWindow()
        }
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        
        // TODO: A lot of work...
        setOnboardingState(inOnboarding: true)
    }
}
