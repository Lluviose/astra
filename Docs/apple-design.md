# Astra · Apple design refresh

The interface follows Apple's iOS 27 direction: restrained color, clearer hierarchy, detailed symbols and fluid controls. It uses the existing iOS 26 Liquid Glass APIs, with the existing iOS 18 fallback; it does not require an iOS 27 SDK.

## Visual system

| Layer | Treatment |
| --- | --- |
| Page | Adaptive system grouped background, 20 pt margins, 24 pt section spacing |
| Reading surfaces | Opaque adaptive cards, continuous 22–24 pt corners, subtle borders and shadows |
| Covers | Muted midnight gradients, thin orbital highlights behind the content, white typography |
| Actions and navigation | Native Liquid Glass, regular Material fallback, 44 pt minimum targets for shared chips and icon buttons |
| Icons | Hierarchical SF Symbols on concentric rounded tiles, fine highlight edges, consistent optical scale |
| Color | System blue emphasis, rose / teal / gold reserved for semantic categories |

The overview leads with the date and page identity, then the summary and recording actions. Pending work and navigation entries precede secondary content. Shared cards carry the same language through the roster, timeline, gallery, achievements, statistics and profile views. Settings groups appearance near the top and uses a consistent icon rail.

## Motion and accessibility

- Shared press response: 0.28 s spring, damping 0.78; screen / selection response: 0.42 s spring, damping 0.86.
- The overview enters with a small 12 pt translation and a maximum 80 ms stagger. No decorative loop runs in the background.
- Reduce Motion replaces new translation / scale responses with short fades and keeps the tab bar expanded.
- Reduce Transparency or Increase Contrast gives custom glass controls opaque backgrounds and stronger borders.
- Accessibility text sizes stack overview actions and navigation tiles, expand roster summaries and use menu pickers for timeline scope and appearance.
- Selected chips include a checkmark. Decorative symbols are excluded from VoiceOver. Record names and photos retain their existing masking behavior.

## Review in Xcode

`App/Sources/Design/DesignPreviews.swift` includes interactive light, dark and accessibility component previews. They use fixture text and do not access the local data store.

Run the existing `make test` / PR validation workflow for SwiftUI compilation and the domain / data safety suite. Visual review should cover a small iPhone and iPad, empty and populated data, all tabs, recording and profile sheets, press / selection responses, light / dark appearance, large text, Reduce Motion and Reduce Transparency. A successful unit-test run alone does not verify those visual states.

## References

- [Apple iOS 27](https://www.apple.com/os/ios/)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
