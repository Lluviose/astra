# Astra · Apple design refresh

The interface follows Apple's iOS 27 direction: restrained color, clearer hierarchy, detailed symbols and fluid controls. It uses the existing iOS 26 Liquid Glass APIs, with the existing iOS 18 fallback; it does not require an iOS 27 SDK.

## Visual system

| Layer | Treatment |
| --- | --- |
| Page | Adaptive system grouped background, 20 pt margins, 24 pt section spacing |
| Reading surfaces | Opaque adaptive cards, continuous 22–24 pt corners, a hairline border, a contact shadow plus a soft ambient shadow, and a top highlight in dark appearance |
| Covers | One `CoverStyle` per page (`midnight`, `velvet`, `gilded`, `tide`, `dossier`), rendered as a 3 × 3 `MeshGradient` with a light source in the top-left corner, thin orbital rings and white typography |
| Actions and navigation | Native Liquid Glass, regular Material fallback, 44 pt minimum targets for shared chips and icon buttons; `SurfaceButtonLabel` for full-width actions on light cards |
| Icons | Hierarchical SF Symbols on concentric rounded tiles; `Medallion` for achievements with a tier ring and a lock while dark; solid tinted squares with white glyphs in Settings |
| Pickers | `PillPicker`: capsules with one filled selection that slides between options (timeline scope, ranking metric, achievement chapters) |
| Meters | `MeterBar`: thin capsule with a springing fill and a highlight at the tip (rank progress, scores, achievements, insights) |
| Charts | Swift Charts for the monthly outcome trend, with a dashed monthly-average rule |
| Color | System blue emphasis; rose / teal / gold / iris reserved for semantic categories |

The overview leads with the date and page identity, then the cover with the rank meter, then recording actions. Pending work and navigation entries precede secondary content. The focus card is a light surface with the companion's own palette faded into its corners. Shared cards carry the same language through the roster, timeline, gallery, achievements, statistics and profile views.

## Motion

- Shared press response: 0.28 s spring, damping 0.78; screen / selection response: 0.42 s spring, damping 0.86; emphasis (covers, overlays): 0.56 s, damping 0.84; settle (meters, rings, numbers): 0.34 s, damping 0.9.
- The overview enters with a 12 pt translation, a 0.985 scale and a maximum 80 ms stagger. Cards ease in as they scroll into view (`scrollReveal`).
- Pulling past the top of the overview stretches the cover slightly and spins the star mark; the orbit of the mark draws itself once on appearance.
- Only the overview cover drifts: one mesh control point moves at 20 fps on a 14 s cycle. It pauses under Reduce Motion, Low Power Mode, or when the scene is inactive. No other decorative loop runs.
- Score rings draw from zero on appearance; numbers use numeric text transitions; medallions bounce once when a sheet or unlock overlay opens.
- Gallery cards open profiles with the iOS 18 zoom navigation transition.

## Accessibility

- Reduce Motion replaces translation / scale responses with short fades, keeps the tab bar expanded, stops the cover drift and the pull-to-spin.
- Reduce Transparency or Increase Contrast gives custom glass controls opaque backgrounds and stronger borders.
- Accessibility text sizes stack overview actions and navigation tiles, expand roster summaries, and use menu pickers for timeline scope and appearance.
- Selected chips include a checkmark; pill pickers expose the selected trait. Decorative symbols and meters are excluded from VoiceOver or expose a percentage value. Record names and photos retain their existing masking behavior.

## Review in Xcode

`App/Sources/Design/DesignPreviews.swift` includes interactive light, dark and large-text component previews: cover, pill picker, meters, medallions, chips and surface buttons. They use fixture text and do not access the local data store. Reduce Motion, Reduce Transparency and Increase Contrast are read-only SwiftUI environment values; enable them in Simulator Settings → Accessibility → Display & Text Size / Motion to review those modes.

Run the existing `make test` / PR validation workflow for SwiftUI compilation and the domain / data safety suite. Visual review should cover a small iPhone and iPad, empty and populated data, all tabs, recording and profile sheets, press / selection responses, light / dark appearance, large text, Reduce Motion and Reduce Transparency. A successful unit-test run alone does not verify those visual states.

## References

- [Apple iOS 27](https://www.apple.com/os/ios/)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [MeshGradient](https://developer.apple.com/documentation/swiftui/meshgradient)
- [Zoom navigation transitions](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:))
