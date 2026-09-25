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
