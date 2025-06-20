//
//  AppMenuController.swift
//  Mythic
//

import SwiftUI
import Combine

public final class AppMenuController {
    private var checkForUpdatesMenuItem: NSMenuItem
    private var restartOnboardingMenuItem: NSMenuItem
    private var showSettingsMenuItem: NSMenuItem
    
    private let showAboutSubject = PassthroughSubject<Void, Never>()
    private let showSettingsSubject = PassthroughSubject<Void, Never>()
    private let restartOnboardingSubject = PassthroughSubject<Void, Never>()
    private let checkForUpdatesSubject = PassthroughSubject<Void, Never>()
    
    public var showAboutPublisher: AnyPublisher<Void, Never> {
        showAboutSubject.eraseToAnyPublisher()
    }
    public var showSettingsPublisher: AnyPublisher<Void, Never> {
        showSettingsSubject.eraseToAnyPublisher()
    }
    public var restartOnboardingPublisher: AnyPublisher<Void, Never> {
        restartOnboardingSubject.eraseToAnyPublisher()
    }
    public var checkForUpdatesPublisher: AnyPublisher<Void, Never> {
        checkForUpdatesSubject.eraseToAnyPublisher()
    }
    
    public init() {
        checkForUpdatesMenuItem = NSMenuItem()
        restartOnboardingMenuItem = NSMenuItem()
        showSettingsMenuItem = NSMenuItem()
        buildMainMenu()
    }
    
    private func localize(_ string: LocalizedStringResource) -> String {
        return String(localized: string)
    }
    
    private func format(_ string: String, _ arguments: CVarArg...) -> String {
        return String(format: string, arguments: arguments)
    }
    
    private func systemImage(_ systemImage: String) -> NSImage? {
        return NSImage(systemSymbolName: systemImage, accessibilityDescription: .none)
    }
    
    private func buildMainMenu() {
        let mainMenu = NSMenu()
        
        mainMenu.addItem(makeAppMenu())
        mainMenu.addItem(makeEditMenu())
        mainMenu.addItem(makeViewMenu())
        mainMenu.addItem(makeWindowMenu())
        mainMenu.addItem(makeHelpMenu())
        
        NSApp.mainMenu = mainMenu
    }
    
    private func makeAppMenu() -> NSMenuItem {
        let appName = AppDelegate.applicationBundleName
        let item = NSMenuItem()
        let menu = NSMenu(title: appName)

        // About Mythic
        let aboutMenuItem = NSMenuItem(title: format(localize("appMenu.about"), appName),
                                   action: #selector(handleShowAbout),
                                   keyEquivalent: "")
        aboutMenuItem.target = self
        aboutMenuItem.image = systemImage("info.circle")
        menu.addItem(aboutMenuItem)
        
        // Check For Updates...
        checkForUpdatesMenuItem = NSMenuItem(
            title: localize("appMenu.checkForUpdates"),
            action: #selector(handleCheckForUpdates),
            keyEquivalent: ""
        )
        checkForUpdatesMenuItem.target = self
        checkForUpdatesMenuItem.image = systemImage("sparkles.2")
        menu.addItem(checkForUpdatesMenuItem)
        
        // ---
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        showSettingsMenuItem = NSMenuItem(
            title: localize("appMenu.settings"),
            action: #selector(handleShowSettings),
            keyEquivalent: ","
        )
        showSettingsMenuItem.target = self
        showSettingsMenuItem.image = systemImage("gear")
        menu.addItem(showSettingsMenuItem)
        
        // Restart Onboarding
        restartOnboardingMenuItem = NSMenuItem(
            title: localize("appMenu.restartOnboarding"),
            action: #selector(handleRestartOnboarding),
            keyEquivalent: ""
        )
        restartOnboardingMenuItem.target = self
        menu.addItem(restartOnboardingMenuItem)
        
        // ---
        menu.addItem(NSMenuItem.separator())
        
        // Services...
        let servicesMenuItem = NSMenuItem(title: localize("appMenu.services"), action: nil, keyEquivalent: "")
        servicesMenuItem.image = systemImage("gearshape.2")
        servicesMenuItem.submenu = NSApp.servicesMenu
        menu.addItem(servicesMenuItem)
        
        // ---
        menu.addItem(NSMenuItem.separator())
        
        // Hide Mythic
        menu.addItem(withTitle: format(localize("appMenu.hideApp"), appName),
                     action: #selector(NSApplication.hide(_:)),
                     keyEquivalent: "h")

        // Hide Others
        let hideOthersMenuItem = NSMenuItem(title: localize("appMenu.hideOthers"),
                                            action: #selector(NSApplication.hideOtherApplications(_:)),
                                            keyEquivalent: "h")
        hideOthersMenuItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthersMenuItem)
        
        // Show all
        menu.addItem(withTitle: format(localize("appMenu.showAll"), appName),
                     action: #selector(NSApplication.unhideAllApplications(_:)),
                     keyEquivalent: "")
        
        // ---
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(withTitle: format(localize("appMenu.quit"), appName),
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        
        item.submenu = menu
        return item
    }

    private func makeEditMenu() -> NSMenuItem {
        let menu = NSMenu(title: localize("appMenu.edit"))
        
        menu.addItem(withTitle: localize("appMenu.undo"),
                     action: Selector(("undo:")),
                     keyEquivalent: "z")
        menu.addItem(withTitle: localize("appMenu.redo"),
                     action: Selector(("redo:")),
                     keyEquivalent: "Z")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: localize("appMenu.cut"),
                     action: #selector(NSText.cut(_:)),
                     keyEquivalent: "x")
        menu.addItem(withTitle: localize("appMenu.copy"),
                     action: #selector(NSText.copy(_:)),
                     keyEquivalent: "c")
        menu.addItem(withTitle: localize("appMenu.paste"),
                     action: #selector(NSText.paste(_:)),
                     keyEquivalent: "v")
        menu.addItem(withTitle: localize("appMenu.selectAll"),
                     action: #selector(NSText.selectAll(_:)),
                     keyEquivalent: "a")
        
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
    
    private func makeViewMenu() -> NSMenuItem {
        let menu = NSMenu(title: localize("appMenu.view"))
        
        let enterFullScreenMenuItem = NSMenuItem(title: localize("appMenu.enterFullScreen"),
                     action: #selector(NSWindow.toggleFullScreen(_:)),
                     keyEquivalent: "f")
        enterFullScreenMenuItem.keyEquivalentModifierMask = [.function]
        menu.addItem(enterFullScreenMenuItem)
        
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
    
    private func makeWindowMenu() -> NSMenuItem {
        let menu = NSMenu(title: localize("appMenu.window"))
        
        let closeMenuItem = NSMenuItem(title: localize("appMenu.close"),
                                       action: #selector(NSWindow.performClose(_:)),
                                       keyEquivalent: "w")
        closeMenuItem.image = systemImage("xmark")
        menu.addItem(closeMenuItem)
        menu.addItem(withTitle: localize("appMenu.minimize"),
                     action: #selector(NSWindow.performMiniaturize(_:)),
                     keyEquivalent: "m")
        menu.addItem(withTitle: localize("appMenu.zoom"),
                     action: #selector(NSWindow.performZoom(_:)),
                     keyEquivalent: "")
        
        NSApp.windowsMenu = menu
            
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
    
    private func makeHelpMenu() -> NSMenuItem {
        let menu = NSMenu(title: localize("appMenu.help"))
        
        let visitDocsMenuItem = NSMenuItem(title: localize("appMenu.visitDocs"),
                                           action: #selector(handleVisitDocs),
                                           keyEquivalent: "")
        visitDocsMenuItem.target = self
        menu.addItem(visitDocsMenuItem)
        
        let item = NSMenuItem()
        item.submenu = menu
        NSApp.helpMenu = menu
        return item
    }
    
    public func setRestartOnboardingEnabled(_ enabled: Bool) {
        restartOnboardingMenuItem.isHidden = !enabled
        showSettingsMenuItem.isHidden = !enabled
    }
    
    @objc private func handleShowAbout() {
        showAboutSubject.send()
    }
    
    @objc private func handleCheckForUpdates() {
        checkForUpdatesSubject.send()
    }
    
    @objc private func handleRestartOnboarding() {
        restartOnboardingSubject.send()
    }
    
    @objc private func handleShowSettings() {
        showSettingsSubject.send()
    }
    
    @objc private func handleVisitDocs() {
        if let url = URL(string: "https://docs.getmythic.app/") {
            NSWorkspace.shared.open(url)
        }
    }
}
