# Mythic UI redesign plan

Branch: `feat/ui-redesign` (from `feat/steam-support-v2` @ `6470edc`).
Scope: `Mythic/Views/**` and the scenes/commands in `MythicApp.swift`.
Constraints: macOS 14 deployment target, Swift 6, no new dependencies, no new files, no changes to
`Utilities/`, persistence keys, or the Steam sign-in security code. Written without Xcode, so every
change uses APIs already proven in this codebase or available since macOS 14 (newer ones are guarded).

Existing translated string keys (105 of 353 in `Localizable.xcstrings`) are kept verbatim wherever the
wording is acceptable; only untranslated or misleading strings are reworded.

## Audit findings → changes

### App shell (`MythicApp`, `ContentView`)

| Finding | Change |
| --- | --- |
| Sidebar uses `NavigationLink(destination:)` with no selection, so nothing can drive navigation (menus, keyboard). | Selection-driven `List(selection:)` + `detail` switch; selection published with `focusedSceneValue`. |
| A second `List` is bolted under the sidebar for Operations; version/update blocks float outside the list. | Operations is a normal row with a queue-count badge; update prompt and debug versions sit in a bottom `safeAreaInset`. |
| No keyboard shortcuts for navigation or common actions; no Toggle Sidebar command. | View menu: ⌘1–⌘6 for sections, `SidebarCommands`. File menu: Import Game… (⌘I), Refresh Library (⌘R). Help menu: Mythic Support. |
| Offline indicator is an unlabeled image. | Labeled toolbar item with accessibility label. |
| Help menu typo ("Games compability"). | Fixed. |

### Home / Library / cards

| Finding | Change |
| --- | --- |
| White text is drawn straight onto artwork (hero, grid cards before macOS 26, list cards). | Shared `ReadabilityScrim` gradient behind text; stronger with Increase Contrast / Reduce Transparency. |
| Icon-only buttons (play, install, more, info, cancel…) have no accessible names. | `Label` + `.labelStyle(.iconOnly)` and explicit `accessibilityLabel`s that include the game title. |
| Game cards are a flat pile of elements for VoiceOver; artwork is announced. | `accessibilityElement(children: .contain)` with a card label (title, storefront, state); artwork hidden. |
| Titles are single-line and truncate. | Two lines + full title tooltip. |
| Empty states use emoji, private-use SF Symbol glyphs, and detached buttons; no "no results" state for search/filters. | `ContentUnavailableView` with actions; new no-results state with Clear Filters. |
| Shimmer, fade-in, hover expansion and layout animations ignore Reduce Motion. | All gated on `accessibilityReduceMotion`. |
| Image load failures render a full error essay inside a 200 pt card. | Compact placeholder; error in tooltip. |
| Favourite star and "Update available" rely on glyph only. | Accessibility labels; menu items read Favourite / Remove from Favourites. |
| "Delete" opens the uninstall sheet; "Force-refresh". | "Uninstall…", "Refresh Library". |
| Active library filters are invisible. | Filter button fills when filters are active and exposes the count. |

### Operations

| Finding | Change |
| --- | --- |
| Cancelled state shows a checkmark; queue controls are unlabeled icons. | Distinct symbols plus labels; progress views get labels. |
| Emoji / shouting empty states. | Plain, consistent copy. |

### Containers

| Finding | Change |
| --- | --- |
| One `isPresented` flag is shared by every row, so Settings/Delete can target the wrong container. | Item-based sheet/alert keyed on the selected container. |
| With the engine installed and no containers, the list renders nothing; the empty state only appears when the engine is missing. | Engine installed + none → empty state with Create; engine missing → install prompt. |
| Toolbar items use `.confirmationAction`; icon-only. | `.primaryAction` with labels. |
| Configuration sheet is one row of six buttons forced to fixed size. | Settings form + "Tools" section with described rows; Done as default button. |
| Winetricks: selection by tap gesture and colour; chips removable only by click. | Checkbox toggles; chips are buttons with remove labels; default/cancel shortcuts. |
| Creation sheet: field label is a sentence, "Done", warning is tooltip-only. | "Name", "Create" default action, visible warning text. |

### Sheets (install, import, settings, engine, Rosetta, status)

| Finding | Change |
| --- | --- |
| No default / cancel keyboard shortcuts anywhere. | `.keyboardShortcut(.cancelAction / .defaultAction)`; destructive confirmations are never the default. |
| Engine/Rosetta sheets cannot be dismissed at the disclaimer; body text has hard line breaks. | "Not Now" button; reflowed text. |
| Game settings: unlabeled text field, empty-title button, click-to-delete chips, white-on-image hero. | Labels, remove buttons, scrim; Esc closes. |
| `type: "Uninstall"` is passed as a plain `String` and never localised. | `String(localized:)` at call sites. |
| Warning triangles carry meaning only via tooltip. | Accessibility labels and visible text where space allows. |
| Import tabs all share one icon; Steam tab's "Cancel" cancels nothing. | Distinct icons; "Done". |
| Star rating is hover/tap only. | Buttons + adjustable accessibility action. |

### Windows (Settings, About, Support, Store, sign-in, updater, onboarding)

| Finding | Change |
| --- | --- |
| Settings on macOS 14 is one long form; tab names disagree ("Downloads" vs "Operations"); empty "Mythic" updates section; destructive buttons say "OK". | Toolbar-tab `TabView` on all versions, fixed width, consistent names, verb-labelled destructive buttons. |
| About hides all text on hover and animates regardless of Reduce Motion. | Text always visible; static gradient under Reduce Motion; selectable version. |
| Support is loose views in an AppKit window; "Recieve Help" typo. | Grouped form of links; typo fixed. |
| Store: Back/Forward are permanently disabled (state never leaves the web view), any re-render reloads the home page, toolbar items unlabeled and misplaced. | `WebViewNavigator` drives real back/forward/reload; labeled items in `.navigation` / `.primaryAction`. |
| Accounts: side-by-side cards overflow; sign-out intent shown by hover colour; Epic sign-out errors are dropped; Steam alert has no Cancel. | Stacked rows, explicit roles, both error alerts attached. |
| Steam sign-in sheet has no way out and errors are red text only. | Visual-only header with title and Cancel; error with icon. Auth code untouched. |
| Onboarding / update preview: white text over a gradient that includes the light window colour; progress dots unlabeled; percent only on hover. | Dark gradient stop + dark colour scheme for controls; "Step x of y" always visible; default-action Next. |
| Updater alerts lack keyboard shortcuts; 60 % opacity text. | Shortcuts; full-contrast text. |

## Deliberately out of scope

- `Utilities/` (including `OperationButton`, `Engine.NotInstalledView`) and all persistence keys.
- Steam nonce generation, `WKWebView` configuration, navigation policy and callback verification.
- Context menus on cards (needs sheet state lifted out of `GameCard.MenuView`).
- Legacy `StopDownloadAlert`, stub `HeroGameCard` / `DownloadCard`.
