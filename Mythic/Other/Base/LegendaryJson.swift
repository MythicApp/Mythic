//
//  Test1.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 22/9/2023.
//

import Foundation
import SwiftyJSON

struct LegendaryJson {
    static func getGames() -> (appNames: [String], appTitles: [String]) {
        guard Legendary.signedIn(useCache: true) else { return ([], []) }
        let json = try? JSON(
            data: Legendary.command(args: ["list-installed","--json"], useCache: true).stdout
        )
        
        var appNames: [String] = []
        var appTitles: [String] = []
        for game in json! {
            appNames.append(String(describing: game.1["app_name"]))
            appTitles.append(String(describing: game.1["app_title"]))
        }
        return (appNames, appTitles)
    }
    
    static func getInstallable() -> (appNames: [String], appTitles: [String]) {
        guard Legendary.signedIn(useCache: true) else { return ([], []) }
        let json = try? JSON(
            data: Legendary.command(args: ["list","--platform","Windows","--third-party","--json"], useCache: true).stdout
        )
        var appNames: [String] = []
        var appTitles: [String] = []
        for game in json! {
            appNames.append(String(describing: game.1["app_name"]))
            appTitles.append(String(describing: game.1["app_title"]))
        }
        return (appNames, appTitles)
    }
    
    static func getImages() -> [String: String] {
        guard Legendary.signedIn(useCache: true) else { return [:] }
        let json = try? JSON(
            data: Legendary.command(args: ["list","--platform","Windows","--third-party","--json"], useCache: true).stdout
        )
        
        var gamePicURLS: [String: String] = [:]
        
        for game in json! {
            let appName = String(describing: game.1["app_name"])
            if let keyImages = game.1["metadata"]["keyImages"].array {
                let dieselGameBoxTallImages = keyImages.filter { $0["type"].string == "DieselGameBoxTall" }
                if let imageUrl = dieselGameBoxTallImages.first?["url"].string {
                    gamePicURLS[appName] = imageUrl
                }
            }
        }
        return gamePicURLS
    }
    
    static func getAppNameFromTitle(appTitle: String) -> String {
        let json = try? JSON(
            data: Legendary.command(args: ["info", appTitle, "--json"], useCache: true).stdout
        )
        return json!["game"]["app_name"].stringValue
    }
    
    static func getTitleFromAppName(appName: String) -> String {
        let json = try? JSON(
            data: Legendary.command(args: ["info", appName, "--json"], useCache: true).stdout
        )
        return json!["game"]["title"].stringValue
    }
}
