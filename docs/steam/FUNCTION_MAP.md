# Steam Support — Function Map & Contract (v2, on upstream MythicApp/Mythic)

Original implementation map; signatures below reflect subsequent integration and security fixes.

**Toolchain constraints:** Swift 6 language mode (`SWIFT_VERSION = 6.0`), macOS 14 deployment target, app not sandboxed,
hardened runtime. Swift 6 mode means **global/static mutable state is a compile error** unless protected: use
`let` + a lock type (`OSAllocatedUnfairLock<State>` from `os`) or `nonisolated(unsafe)` with a lock and a comment. `@MainActor`
APIs (`GameDataStore`, `Game.operationManager`, `Game.launch/update/move`) must be called from the main actor (`await` across).
Match upstream style: short file header (`//\n//  File.swift\n//  Mythic\n//`), `Logger.custom(category:)`, `UserDefaults.standard`
(upstream no longer has the `files`/`defaults`/`workspace` globals), `String(localized:)` for user-facing strings, SwiftLint clean.

## Architecture recap (upstream)

* `Game` (`Utilities/Game/Game.swift`) is an `@Observable` Codable base class. Subclasses: `EpicGamesGame`, `LocalGame`, and the
  placeholder `SteamGame`. Subclasses override `storefront`, `computedVerticalImageURL`, `computedHorizontalImageURL`,
  `getSupportedPlatforms()`, `isUpdateAvailable`, `_checkIfGameIsRunning`, `_launch`, `_update`, `_move`, `_verifyInstallation`.
* State lives in `installationState: .uninstalled | .installed(location: URL, platform: Game.Platform)`.
* Polymorphic persistence: `AnyGame` decodes by `storefront`. Library = `GameDataStore.shared.library: Set<Game>` (MainActor),
  filled by `refreshFromStorefronts(...)`.
* Actions are `GameOperation(game:type:function:)` queued with `Game.operationManager.queueOperation(_:)`.
  Managers: `protocol GameManager` / `StorefrontGameManager` (`Utilities/GameManager/GameManager.swift`),
  pattern = typed static funcs + a protocol-conformance extension that casts `Game` → concrete type (see `EpicGamesGameManager`).

## Steam design

* **Identity:** Steam OpenID 2.0 in a WKWebView; callback intercepted (never loaded) and verified server-side with
  `check_authentication`. Only the verified SteamID64 is stored (Keychain). *(Done: `SteamAuth`.)*
* **Owned games:** Web API `IPlayerService/GetOwnedGames` (needs Web API key). *(Done: `SteamWebAPI`.)*
* **Installed games:** `libraryfolders.vdf` + `appmanifest_<appid>.acf` from native `~/Library/Application Support/Steam` and
  Windows Steam in each Wine container (`drive_c/Program Files (x86)/Steam`). *(Parser done: `VDF`.)*
* **Install / launch / uninstall / verify:** handed to the real Steam client via `steam://` URLs (native: `NSWorkspace.open`;
  Wine: run `steam.exe` in the container via `Wine.transformProcess` + `Wine.assembleEnvironmentVariables`). Mythic never downloads depots.
* **Game identity:** `SteamGame(id: "steam_<appid>")`. AppIDs validated `^[0-9]{1,10}$` before any URL/path/argument use.
* **Secrets:** `.env` → `Mythic/Config/Steam.xcconfig` (`#include? "../../.env"`) → Info.plist `MythicSteamWebAPIKey`,
  `MythicSteamOpenIDRealm` → `SteamConfig`. A user key in Keychain overrides the bundled one.

## Files & owners

| File | Owner | Status |
|---|---|---|
| `Utilities/Steam/VDFParser.swift`, `SteamKeychain.swift`, `SteamConfig.swift`, `SteamAuth.swift`, `SteamWebAPI.swift` | Orchestrator | ported, read-only for agents |
| `Utilities/Steam/SteamClient.swift` | Agent A | new |
| `Utilities/Game/SteamGame.swift` | Agent A | rewrite placeholder |
| `Utilities/GameManager/SteamGameManager.swift` | Agent A | new |
| `Views/Unified/Windows/SteamWebAuthView.swift` | Agent C | new |
| `Views/Navigation/AccountsView.swift` (add Steam card) | Agent C | edit |
| `Views/Unified/Windows/SettingsView.swift` (fill the `Section("Steam")` stub only) | Agent C | edit |
| `Views/Unified/Sheets/GameImportView/SteamGameImportView.swift` | Agent G | new |
| `Views/Unified/Sheets/GameImportView/GameImportView.swift` (Steam tab) | Agent G | edit |
| `Views/Unified/Sheets/GameInstallationView/Steam/SteamGameUninstallationView.swift` | Agent G | new |
| `Views/Unified/Components/GameCard/GameCard+Extensions.swift` (Steam install + uninstall dispatch) | Agent G | edit |
| `Utilities/Game/Game+Extensions.swift` (`Storefront.steam`), `Utilities/Game/Game.swift` (`AnyGame`), `Utilities/GameDataStore.swift` (steam refresh), `project.pbxproj`, `Info.plist`, `Config/Steam.xcconfig`, `.env.example`, `.gitignore` | Orchestrator | edit |

---

## Already implemented (read them; call exactly)

```swift
enum VDF { indirect enum Node { subscript(key:) -> Node?; var stringValue: String?; var children: [(key: String, value: Node)] }
           static func parse(_ text: String) throws -> Node; static func parse(contentsOf url: URL) throws -> Node }
enum SteamKeychain { enum Key { case steamID, webAPIKey }; static func set(_:for:) throws; static func get(_:) -> String?; static func delete(_:) }
enum SteamConfig { static var webAPIKey: String?; static var userWebAPIKey: String?; static func setUserWebAPIKey(_ key: String?) throws
                   static var openIDRealm: URL; static var openIDReturnTo: URL }
enum SteamAuth { static var currentSteamID: String?; static var isSignedIn: Bool; static func makeLoginURL(nonce: String) -> URL
                 static func isCallback(_ url: URL) -> Bool
                 static func verify(callbackURL: URL, expectedNonce: String, session: URLSession = SteamWebAPI.session) async throws -> String
                 static func completeSignIn(steamID: String) throws; static func signOut()   // keychain only
                 struct VerificationError: LocalizedError }
enum SteamWebAPI { struct OwnedGame { appid: Int; name: String?; playtimeForever: Int?; imageIconURL: String? }
                   struct PlayerSummary { steamid: String; personaname: String; avatarfull: String? }
                   struct MissingAPIKeyError; struct HTTPError
                   static func getOwnedGames(steamID: String, session: URLSession = SteamWebAPI.session) async throws -> [OwnedGame]
                   static func getPlayerSummary(steamID: String, session: URLSession = SteamWebAPI.session) async throws -> PlayerSummary? }
```

## Agent A — `SteamClient.swift` (Steam client discovery + steam:// actions; no Game-model logic beyond building SteamGames)

```swift
enum SteamClient {
    static let log: Logger                                   // Logger.custom(category: "steamClient")
    static let gameIDPrefix = "steam_"
    static let clientBundleIdentifier = "com.valvesoftware.steam"

    static func isValidAppID(_ appID: String) -> Bool        // ^[0-9]{1,10}$
    static func appID(fromGameID id: String) -> String?      // strips prefix, validates
    static func gameID(forAppID appID: String) -> String?    // nil if invalid

    static var isNativeClientInstalled: Bool                 // NSWorkspace.shared.urlForApplication(withBundleIdentifier:)
    static var nativeSteamRoot: URL?                         // ~/Library/Application Support/Steam (if directory)
    static func windowsSteamRoot(containerURL: URL) -> URL?  // drive_c/Program Files (x86)/Steam or Program Files/Steam containing steam.exe
    struct InstallLocation: Hashable, Sendable { let steamRoot: URL; let containerURL: URL?; var platform: Game.Platform }
    static var installLocations: [InstallLocation]           // native + each Wine.containerURLs with Steam (sorted)
    static func libraryFolders(of location: InstallLocation) -> [URL]  // steamapps dirs; root/steamapps always; libraryfolders.vdf entries;
                                                             // Wine: only "C:\..." paths mapped into drive_c, reject ".." / "."
    struct InstalledApp: Hashable, Sendable { let appID: String; let name: String; let installDirectory: URL; let location: InstallLocation
                                              let stateFlags: Int; var isUpdateRequired: Bool /* StateFlags & 2 */ }
    static func installedApps(forceRefresh: Bool = false) -> [InstalledApp]   // cached ≤5 s behind OSAllocatedUnfairLock
    static func installedApp(appID: String) -> InstalledApp?
        // manifest rules: appmanifest_<id>.acf, 8 MiB cap (VDF does it), AppState.appid == id, StateFlags & 4 (fully installed),
        // installdir: no "/" "\\" "..", resolved (standardized + symlinks) path must stay inside <steamapps>/common/

    static func imageURL(appID: String, vertical: Bool) -> URL?
        // vertical: https://cdn.cloudflare.steamstatic.com/steam/apps/<id>/library_600x900_2x.jpg ; else .../header.jpg

    /// steam://<action>/<appid>; actions: "rungameid", "install", "uninstall", "validate". nil for invalid appID/action.
    static func steamURL(action: String, appID: String) -> URL?
    struct ClientNotInstalledError: LocalizedError; struct InvalidAppIDError: LocalizedError
    /// Opens the action in the right client: native → NSWorkspace.shared.open(url) (throw if returns false / client missing);
    /// windows → run "<steamRoot>/steam.exe" with arguments (rungameid: ["-applaunch", id] + extraArguments; others: [url.absoluteString])
    /// via Process + Wine.transformProcess(process, containerURL:) + environment = Wine.assembleEnvironmentVariables(forContainerAtURL:);
    /// requires Engine installed (throw Engine.NotInstalledError — check how LocalGameManager/Epic do it). Never use a shell.
    static func perform(action: String, appID: String, platform: Game.Platform, containerURL: URL?, extraArguments: [String] = []) async throws

    /// Library assembly for GameDataStore. Owned games only when SteamAuth.currentSteamID != nil && SteamConfig.webAPIKey != nil.
    /// Installed → .installed(location: installDirectory, platform: location.platform) and containerURL = location.containerURL.
    static func fetchInstalledGames() -> [SteamGame]
    @MainActor static func fetchOwnedGames() async throws -> [SteamGame]? // nil when sign-in or key is unavailable
}
```

## Agent A — `SteamGame.swift` (replace placeholder; remove `@available(*, deprecated…)`)

```swift
class SteamGame: Game {
    override var storefront: Storefront? { .steam }
    var appID: String? { SteamClient.appID(fromGameID: id) }
    convenience init?(appID: String, title: String, installationState: InstallationState, containerURL: URL? = nil) // nil if invalid
    override var computedVerticalImageURL: URL?; override var computedHorizontalImageURL: URL?
    override func getSupportedPlatforms() -> Set<Game.Platform>?   // installed → [platform]; else nil
    override var isUpdateAvailable: Bool?                          // installedApp?.isUpdateRequired
    override func _checkIfGameIsRunning(location:platform:) -> Bool // macOS: running app bundle inside location; windows: false
    nonisolated override func _launch() async throws   → try await SteamGameManager.launch(game: self)
    nonisolated override func _update() async throws   → try await SteamGameManager.update(game: self, qualityOfService: .default)
    nonisolated override func _move(from:to:) async throws → throw SteamGameManager.UnsupportedOperationError()
    nonisolated override func _verifyInstallation() async throws → try await SteamGameManager.repair(game: self, qualityOfService: .default)
    required init(from decoder:) / override init(...) as the placeholder has
}
```
(Mirror `EpicGamesGame`'s use of `nonisolated override` exactly.)

## Agent A — `SteamGameManager.swift` (mirror `EpicGamesGameManager` / `LocalGameManager` structure)

```swift
class SteamGameManager {
    static var log: Logger { .custom(category: "SteamGameManager") }
    struct UnsupportedOperationError: LocalizedError   // "Steam manages this; use the Steam client."
    @discardableResult @MainActor static func launch(game: SteamGame) async throws -> GameOperation      // type .launch, action "rungameid", extraArguments: game.launchArguments; minimise per "minimiseOnGameLaunch"
    @discardableResult static func install(game: SteamGame, platform: Game.Platform, containerURL: URL? = nil, qualityOfService: QualityOfService) async throws -> GameOperation // "install"
    @discardableResult static func update(game: SteamGame, qualityOfService: QualityOfService) async throws -> GameOperation   // type .update, action "install" (Steam updates on its own; this surfaces the app in the client so the update runs)
    @discardableResult static func repair(game: SteamGame, qualityOfService: QualityOfService) async throws -> GameOperation   // "validate"
    @discardableResult @MainActor static func uninstall(game: SteamGame, persistFiles: Bool) async throws -> GameOperation      // "uninstall" (persistFiles ignored; Steam decides)
    @MainActor static func move(game: SteamGame, to newLocation: URL) async throws -> GameOperation       // throw UnsupportedOperationError
    static func fetchUpdateAvailability(for game: SteamGame) throws -> Bool
    static func isFileVerificationRequired(for game: SteamGame) throws -> Bool  // false
    @MainActor static func importGame(_ game: SteamGame, platform: Game.Platform, at location: URL) async throws  // throw UnsupportedOperationError (Steam installs are auto-detected)
}
extension SteamGameManager: StorefrontGameManager { /* Game → SteamGame casting wrappers, exactly like EpicGamesGameManager */ }
```
Every operation: `let op = GameOperation(game: game, type: <type>) { _ in try await SteamClient.perform(...) }`, then
`Game.operationManager.queueOperation(op)` on the main actor, return `op`. Install/uninstall platform: installed platform if any,
else the `platform` argument / `.macOS` if native client installed else `.windows`. containerURL: installed location's container, else `game.containerURL`.

## Agent C — UI (accounts, auth window, settings)

* `SteamWebAuthView(isPresented: Binding<Bool>, onSignedIn: @escaping (String) -> Void)` — `NSViewRepresentable` `WKWebView`,
  `WKWebsiteDataStore.nonPersistent()`; 16-byte `SecRandomCopyBytes` hex nonce (fail closed); load `SteamAuth.makeLoginURL(nonce:)`;
  `decidePolicyFor`: `SteamAuth.isCallback(url)` → `.cancel`, then `SteamAuth.verify` + `SteamAuth.completeSignIn` once (flag), `onSignedIn`, dismiss.
  Main-frame nav only `https` to hosts `== d || hasSuffix("." + d)` for d in [steamcommunity.com, steampowered.com]; other https
  main-frame links → `NSWorkspace.shared.open` + cancel; non-https → cancel; subresources https only; `createWebViewWith` → same policy, return nil.
  MainActor state, ProgressView, error text. Look at `EpicWebAuthView.swift` for upstream style (window vs sheet) and follow it.
* `AccountsView`: add a second `AccountCard(signedInUser:image: Image("Steam"), storefront: .steam, …)` with its own state; persona via
  `SteamWebAPI.getPlayerSummary` (fallback SteamID; no key → SteamID); sign-in presents `SteamWebAuthView`; sign-out confirmation alert →
  `SteamAuth.signOut()` then `try? await GameDataStore.shared.refreshFromStorefronts(.steam)`; after sign-in also refresh `.steam`.
* `SettingsView`: replace the empty `Section("Steam", isExpanded: .constant(false)) { }.help("Coming Soon")` with a working section:
  `SecureField` for optional personal Web API key → `SteamConfig.setUserWebAPIKey` (show validation error), `Link` to
  https://steamcommunity.com/dev/apikey, "Refresh Steam library" button → `GameDataStore.shared.refreshFromStorefronts(.steam)`.

## Agent G — import, uninstall sheet, game-card dispatch

* `SteamGameImportView(isPresented:)`: lists `SteamClient.installedApps()` grouped by install location (native / container path),
  explains installed Steam games are added automatically, "Refresh" → `try await GameDataStore.shared.refreshFromStorefronts(.steam)` with error display.
  Wire into `GameImportView` (remove `.hidden()`, fill the empty Steam tab, add to the pre-macOS-15 `TabView`).
* `SteamGameUninstallationView(game: Binding<SteamGame>, isPresented:)`: mirror `LocalGameUninstallationView` /
  `EpicGamesGameUninstallationView` using `BaseGameInstallationView`; calls `SteamGameManager.uninstall(game:persistFiles:)`; explain Steam's uninstaller will open.
* `GameCard+Extensions.swift`: `InstallButton` — for `SteamGame`, let the user choose the native client or a Windows
  Steam container, then call `SteamGameManager.install(game:platform:containerURL:qualityOfService:)` with error handling.
  Uninstall sheet `switch game` → add `case let steamGame as SteamGame:` presenting `SteamGameUninstallationView`.
  `VerificationButton` already calls `game.verifyInstallation()` → fine. Do not alter Epic/Local paths.
