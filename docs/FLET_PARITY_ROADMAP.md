# Flet Parity Check and Roadmap (Ruflet)

Last updated: 2026-03-04

## Scope

This document tracks parity against official Flet controls/services docs and current Ruflet runtime support.

Primary references:
- https://docs.flet.dev/controls/
- https://docs.flet.dev/services/

Notes:
- "Implemented" means a concrete control class exists in `ControlFactory::CLASS_MAP`.
- "Mapped-only" means type is known in `TYPE_MAP`, but falls back to generic `Ruflet::Control`.
- Extension packages in Flet (for example `flet-webview`, `flet-geolocator`) are out of core scope unless explicitly adopted.

## Snapshot

- Implemented controls/services with concrete classes: **41**
- Mapped-only controls/services (generic fallback): **47**
- Major Flet controls/services still missing from mapping: **many** (prioritized below)

## Implemented (Concrete Runtime Class)

`alertdialog`, `appbar`, `bottomsheet`, `button`, `checkbox`, `column`, `container`, `cupertinoactionsheet`, `cupertinoalertdialog`, `cupertinobutton`, `cupertinodialogaction`, `cupertinofilledbutton`, `cupertinonavigationbar`, `cupertinoslider`, `cupertinoswitch`, `cupertinotextfield`, `draggable`, `dragtarget`, `elevatedbutton`, `filledbutton`, `floatingactionbutton`, `gesturedetector`, `icon`, `iconbutton`, `image`, `markdown`, `navigationbar`, `navigationbardestination`, `radio`, `radiogroup`, `row`, `snackbar`, `stack`, `tab`, `tabbar`, `tabbarview`, `tabs`, `text`, `textbutton`, `textfield`, `view`

## Mapped-Only (Generic Control Fallback)

`audio`, `banner`, `barchart`, `barchartgroup`, `barchartrod`, `barchartrodstackitem`, `candlestickchart`, `candlestickchartspot`, `canvas`, `card`, `chartaxis`, `chartaxislabel`, `cupertinobottomsheet`, `cupertinocheckbox`, `cupertinodatepicker`, `cupertinopicker`, `cupertinoradio`, `cupertinotimerpicker`, `cupertinotintedbutton`, `datepicker`, `dropdown`, `dropdownm2`, `filledtonalbutton`, `flashlight`, `line`, `linechart`, `linechartdata`, `linechartdatapoint`, `listtile`, `option`, `outlinedbutton`, `piechart`, `piechartsection`, `progressbar`, `radarchart`, `radarcharttitle`, `radardataset`, `radardatasetentry`, `safearea`, `scatterchart`, `scatterchartspot`, `service_registry`, `slider`, `switch`, `timepicker`, `url_launcher`, `video`

## High-Priority Missing (Not Mapped Yet)

### Core controls

- `ListView`
- `GridView`
- `ReorderableListView`
- `ResponsiveRow`
- `DataTable` (+ `DataRow`, `DataColumn`, `DataCell`)
- `ProgressRing`
- `ExpansionPanelList`
- `NavigationDrawer`
- `PopupMenuButton` / menu ecosystem (`MenuBar`, `MenuItemButton`, `SubmenuButton`)
- `SearchBar` / `SearchAnchor`
- `SegmentedButton`
- `Chip`
- `Autocomplete`

### Page-level API parity

- `page.login(...)`
- `page.logout()`
- close parity checks for `page.launch_url(...)` behavior/options vs Flet docs

### Services (core docs)

Mapped/used now:
- `UrlLauncher` (mapped + page helper)
- `Audio`, `Video`, `Flashlight` (mapped, used as service-like controls)

Not yet implemented in core:
- `Clipboard`
- `FilePicker`
- `Connectivity`
- `Share`
- `SecureStorage`
- `SharedPreferences`
- `StoragePaths`
- `PermissionHandler`
- `ScreenBrightness`
- motion/sensor set (`Accelerometer`, `Gyroscope`, `Magnetometer`, etc.)
- `Wakelock`

## Roadmap

### Phase 1: Stabilize Core Parity (near-term)

- [ ] Add concrete classes for currently mapped-only controls used in studio demos:
  - `banner`, `card`, `switch`, `slider`, `dropdown`, `listtile`
- [ ] Complete Cupertino controls already mapped:
  - `cupertino_bottom_sheet`, `cupertino_picker`, `cupertino_date_picker`, `cupertino_timer_picker`, `cupertino_checkbox`, `cupertino_radio`, `cupertino_tinted_button`
- [ ] Add test coverage for dialog/banner open-close lifecycle and payload typing

### Phase 2: Data + Lists + Menus

- [ ] Implement `ListView`, `GridView`, `ReorderableListView`
- [ ] Implement table suite: `DataTable`, `DataRow`, `DataColumn`, `DataCell`
- [ ] Implement menu suite and popup actions
- [ ] Implement `ResponsiveRow`

### Phase 3: Service Layer Expansion

- [ ] Standardize service registration/invoke contract (request/response/event)
- [ ] Add first high-impact services: `Clipboard`, `FilePicker`, `Connectivity`, `Share`, `SharedPreferences`
- [ ] Add storage/services docs and examples in `examples/ruflet_studio`

### Phase 4: Advanced/Optional

- [ ] Charts: move mapped-only chart controls to concrete classes with validation helpers
- [ ] Sensor-related services behind platform capability checks
- [ ] Evaluate extension-pack integration strategy (`flet-*` equivalents)

## Acceptance Criteria Per Control/Service

- [ ] Control has concrete class in `ControlFactory::CLASS_MAP`
- [ ] Type is in registry mapping
- [ ] Event prop mapping covered and tested
- [ ] Studio example exists (or explicit reason not to)
- [ ] Added to parity table in this file
