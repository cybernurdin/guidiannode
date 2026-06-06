# GuardianNode UI Architecture

## Audit Summary

- Existing business logic is concentrated in `ApiService`, `ProfileApiService`, `EmergencyApiService`, `EmergencyCoordinator`, and `SupabaseRealtimeService`.
- The app already supports inbound WhatsApp authentication, profile update, SOS creation, live location sync, nearby alerts, realtime subscriptions, and responder route follow mode.
- Missing quality areas were mostly in presentation: inconsistent spacing, repeated styles, limited state treatment, weak hierarchy, and no durable onboarding/settings shell.
- No police or admin Flutter interfaces were present in the repository during the audit, so the redesign focuses on resident and community-responder flows.

## Implementation Plan

1. Establish shared design tokens and a production-ready `ThemeData`.
2. Create reusable widgets for actions, states, cards, sections, and map overlays.
3. Rebuild auth and onboarding so the entry flow feels official, calm, and fast.
4. Recompose emergency, map, and responder screens around the existing coordinator and API contracts.
5. Add account/settings polish, accessibility passes, tests, and documentation.

## Design Tokens

- Colors live in `lib/core/theme/colors.dart`.
- Typography lives in `lib/core/theme/typography.dart`.
- Spacing, radii, elevation, and motion tokens live in `lib/core/theme/spacing.dart`, `radii.dart`, `elevation.dart`, and `motion.dart`.
- The app theme is defined in `lib/core/theme/theme.dart`.

## Reusable UI Components

The shared widget layer is centered in `lib/core/widgets/` and is intended to cover:

- emergency actions
- semantic banners and badges
- profile, alert, responder, and location cards
- empty/error/loading states
- section headers, action tiles, and bottom-sheet surfaces

Future screens should consume these primitives before introducing one-off styling.

## UI Rules For Future Work

- Keep emergency actions primary and reachable inside the first viewport.
- Reuse semantic colors instead of hardcoding screen-level colors.
- Prefer full-width section bands and extracted repeated items over nested card stacks.
- Treat loading, empty, error, and offline-adjacent states as first-class UI.
- Preserve business logic contracts; presentation adapters are acceptable, backend rewrites are not.
