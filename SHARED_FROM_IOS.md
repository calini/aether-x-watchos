# Files derived from element-x-ios

Source commit: `ad1d7a301` (element-x-ios `develop`, 2026-09-25). Licence: AGPL-3.0-only OR LicenseRef-Element-Commercial.

| Watch file | Source | Changes |
|---|---|---|
| `Packages/CompoundDesignTokens/Sources/CompoundDesignTokens/*` | compound-design-tokens `v11.0.0` `assets/ios/swift` | Dropped `CompoundCoreUIColorTokens.swift`, `CompoundUIColorTokens.swift` (UIKit-only) and `Resources/theme.iife.js`. |
| `Tools/Sourcery/AutoMockable.stencil` | `Tools/Sourcery/AutoMockable.stencil` | Removed iOS-only imports. |
| `ElementXWatch/Sources/Other/SDKListener.swift` | `ElementX/Sources/Other/SDKListener.swift` | `onUpdateClosure` made `fileprivate`; watch listener conformances added in the same file. |
| `ElementXWatch/Sources/Other/SwiftUI/BindableState.swift` | `ElementX/Sources/Other/SwiftUI/ViewModel/BindableState.swift` | None. |
| `ElementXWatch/Sources/Other/SwiftUI/StateStoreViewModelV2.swift` | `ElementX/Sources/Other/SwiftUI/ViewModel/StateStoreViewModelV2.swift` | Removed media provider and content scanner. |
| `ElementXWatch/Sources/Other/CoordinatorProtocol.swift` | `ElementX/Sources/Application/CoordinatorProtocol.swift` | None. |
| `ElementXWatch/Sources/Services/Session/SessionDirectories.swift` | `ElementX/Sources/Services/UserSession/SessionDirectories.swift` | Removed transient-data deletion and the legacy init; added `create()` and watch base directories. |
| `ElementXWatch/Sources/Services/Session/RestorationToken.swift` | `ElementX/Sources/Services/UserSession/RestorationToken.swift` | A cache directory is required (no legacy single-directory tokens). |
| `ElementXWatch/Sources/Services/Session/SessionDelegate.swift` | `ElementX/Sources/Services/UserSession/UserSessionStore.swift` (client session delegate) | Single-account keychain store. |
| `ElementXWatch/Sources/Services/Client/ClientFactory.swift` | `ElementX/Sources/Services/Client/ClientFactory.swift` | URLSession transport, memory-constrained, no search index, no automatic back-pagination, DEBUG reqwest tripwire, no app hooks. |
| `ElementXWatch/Sources/Other/Tracing.swift` | `ElementX/Sources/Other/Logging/Tracing.swift` | Minimal file + system logging, no Sentry. |
| `ElementXWatch/Sources/Services/Room/RoomSummaryPreview.swift` | `ElementX/Sources/Services/Room/RoomSummary/RoomMessageEventStringBuilder.swift` | Plain strings (no attributed prefixes), fixed English copy. |
| `ElementXWatch/Sources/Services/Room/RoomSummaryProvider.swift` | `ElementX/Sources/Services/Room/RoomSummary/RoomSummaryProvider.swift` | Single fixed filter (non-space, joined, deduplicated), incremental summary rebuilds, no pagination UI. |
