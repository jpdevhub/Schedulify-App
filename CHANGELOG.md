# Changelog

All notable changes to Schedulify are documented here.

## [0.2.4] - 2026-06-15
### Added
- Fully migrated app iconography to crisp SVG formats
- Implemented robust light/dark mode drawer theming
- Fixed browser favicon and native splash screen assets

## [0.2.2] - 2026-06-14
### Changed
- Redesigned dual-logo login screen header with transparent assets
- Stabilized Android build pipeline by moving Firebase config to Dart Defines
- Removed legacy Google Services dependencies
- Complete UI theme parity to fix `const_eval` warnings

## [0.2.0] - 2026-05-22
### Added
- Multi-tenant Supabase architecture with dynamic client switching
- College ID gateway screen with vendor registry lookup
- 5-step onboarding setup wizard for new college configuration
- Role-based authentication (super_admin, admin, faculty, student)
- Admin dashboard with 8 management modules
- Timetable lifecycle management (Draft → Published → Archived)
- AI-powered schedule upload and conflict detection via Groq LLaMA

## [0.1.0] - 2026-05-20
### Added
- Initial project scaffolding
- Basic GoRouter navigation with role-based guards
- Dark glassmorphic design system with Riverpod state management
