# Dashboard and Watchlist Refinements

Clean up the Dashboard UI by removing redundant stats and fixing the search usability issues.

## Proposed Changes

### Shoonya API Extensions

#### [MODIFY] [api_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/api_service.dart)
- **`addMultiScripsToMW(String scrips)`**:
    - Call `/NorenWClientTP/AddMultiScripsToMW`.
    - Params: `uid`, `wlname` (e.g., "DEFAULT"), `scrips` (format: `EXCH|TOKEN#EXCH|TOKEN`).
- **`deleteMultiMWScrips(String scrips)`**:
    - Call `/NorenWClientTP/DeleteMultiMWScrips`.
    - Params: same as above.

### Dashboard & Watchlist Refinement

#### [MODIFY] [dashboard_placeholder_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/dashboard_placeholder_page.dart)
- **UI Cleanup**:
    - Remove `_buildQuickStats`.
    - Change `_buildSearchResultsOverlay` to a height-limited `ListView` embedded directly in the main `Column`.
    - **[Implemented] List Item Redesign**:
        - Updated `Watchlist` and `Strategy Strike List` to use a cleaner, column-based layout (Symbol/Exch vs Price/Change).
        - Integrated compact "Delete" (X) buttons.
- **[Implemented] Backend Sync (Watchlist)**:
    - On Init: Call `getMarketWatch` (wlname: 'DEFAULT') to populate `_selectedScrips`.
    - Handle duplicates and fetch initial quotes for valid scrips.
    - When adding a scrip: call `addMultiScripsToMW` then subscribe to WS.
    - When deleting a scrip: call `deleteMultiMWScrips` (waiting for success response), show Feedback SnackBar, then unsubscribe from WS and remove from UI.
- **Layout Robustness**:
    - Wrap the scrip name in `Expanded` in `_buildScripCard`.
    - **Remove `TextOverflow.ellipsis`** from the symbol name to ensure the full name is visible.
    - If needed, use a `Column` or `FittedBox` to handle extremely long names gracefully without layout overflow.

### Configurable Strategy Time & Strike Deletion

#### [MODIFY] [storage_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/storage_service.dart)
- **New Constant**: Add `_keyStrategyTime = 'strategy_time'`.
- **Update `saveStrategySettings`**: Add `strategyTime` parameter.
- **Update `getStrategySettings`**: Return `strategyTime` (default '13:15').

#### [MODIFY] [settings_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/settings_page.dart)
- **UI Component**: Add a row to allow users to set the strategy trigger time via `showTimePicker`.
- **State**: Add `_strategyTime` state variable.
- **Save Logic**: Include `_strategyTime` in the `_saveSettings` call.

#### [MODIFY] [strategy_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/strategy_page.dart)
- **Time Logic**: Update `_checkStrategyCondition` to parse and respect the `strategyTime` from settings.
- **Strike Deletion**:
    - Add a `_deleteStrike(int index)` method.
    - Inside `_deleteStrike`, unsubscribe from the WebSocket for that strike's token.
    - Update the `_strikes` list and call `setState`.
    - Save the updated `_strikes` list to `daily_strategy_capture` via `StorageService`.
- **UI Enhancement**: 
    - Add a `delete` icon next to the price display in the strike card.
- **Persistence**:
    - Ensure `_indexLotSize` and `strategyTime` are correctly handled during initialization.

### Index-Level Lot Size Refinement
- **Source of Truth**: The system now fetches the **standard lot size (`ls`)** directly from the base index (**NIFTY 50** or **SENSEX**) during the initial spot capture.
- **Unified Quantity**: This index lot size is used consistently for all strategy strikes, regardless of individual strike responses.
- **Simplified Calculation**: Final quantity is now strictly `User Settings Lots × Index Lot Size` (e.g., 2 Lots × 75 LS = 150 units for Nifty).
- **Day Persistence**: The captured lot size is saved for the day, ensuring the calculation stays consistent even if the app is restarted.

### Background Strategy Service

#### [NEW] [strategy_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/strategy_service.dart)
- **Singleton Pattern**: Implement as a singleton to maintain state globally.
- **Global Strategy Loop**: 
    - Move the periodic timer (clock) from `StrategyPage` to this service.
    - Continuously check for the strategy trigger time (from Settings).
- **Execution Logic**:
    - Handle spot capture, strike resolution, and strike selection persistence.
    - Manage WebSocket subscriptions for resolved strikes so they update even when the UI is closed.
- **State Management**: Use `ValueNotifier` or similar to expose strikes and capture status to the UI.

#### [MODIFY] [main.dart](file:///d:/FlutterApps/hero_or_zero/lib/main.dart)
- **Service Initialization**: Initialize `StrategyService` and `PnLService` within the `main()` function to ensure they start immediately on app launch.

#### [MODIFY] [strategy_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/strategy_page.dart)
- **UI-Only Refactor**:
    - Remove the internal timer, `_checkStrategyCondition`, and `_captureSpotPrice` logic.
    - Subscribe to `StrategyService` updates to display the current status and resolved strikes.
    - Ensure manual "Test Capture" and "Delete Strike" actions call the service methods.
- **Improved Feedback**:
    - Show `errorMessage` even after `capturedSpotPrice` is set (to catch resolution errors).
    - Show `statusMessage` (e.g., "Resolving contracts...") clearly.
    - Show a `CircularProgressIndicator` while `isResolving` is true.
- **Premium UI Redesign (NEW)**:
    - Redesign `Strategy Status` card with a modern gradient background.
    - Add subtle micro-icons for each data point (Time, Index, State).
    - Use a "Glass" effect with subtle opacity and borders.
    - Group logical information (e.g., Time and State) for better hierarchy.

### SENSEX Resolution Enhancements
- **SENSEX Strike Step**: Use a **100-point step** for SENSEX (instead of 50).
- **Search Robustness**:
    - Try multiple search patterns (e.g., `targetIndex + strike + " CE"`, `targetIndex + strike + "CE"`, etc.).
    - For BSE (SENSEX), the symbols can be variants like `SENSEX85500CE` or `SENSEX 85500 CE`.
- **Diagnostic Logging**: Use `debugPrint` for every step of the resolution process to aid troubleshooting.

### Portfolio-Level Exit Strategy
- **Unified Tracking**: `PnLService` now tracks a single `portfolioPeakProfit` based on the sum of all strategy positions.
- **Configurable Hard Stop**: 
    - Added `exitTime` to `StorageService` (default 15:00).
    - Added a time picker in `SettingsPage` to modify this exit threshold.
- **Unified TSL**: TSL is now calculated on the total portfolio P&L:
    - **Trigger**: Total Profit >= ₹200 × Total Lots.
    - **Gap**: ₹150 × Total Lots.
- **Always-On UI**: The `StrategyPage` now shows a permanent "Portfolio Exit Plan" section with peak profit, current TSL, and the scheduled hard stop time.

### App Signing and Release Preparation
- **Package Renaming**:
    - Changed `namespace` and `applicationId` to `com.android.herozerotrade` in `build.gradle.kts`.
    - Relocated `MainActivity.kt` to the new package directory structure.

### Correct Strategy Quantity Logic
- **[MODIFY] [api_service.dart]**:
    - [x] Correct `prdty` to `prctyp` in `ApiService.placeOrder`
    - [x] Add `ordersource: 'API'` in `ApiService.placeOrder`
- **[MODIFY] [strategy_page.dart]**:
    - [x] Update `StrategyPage._placeOrders` to use `M` (NRML) as product
    - [x] Ensure correct `exch` (NFO/BFO) and `qty` are passed from `StrategyPage`
    - [x] **[Implemented] Dynamic Quantity**: Capture `ls` from `GetOptionChain` using resolved strike's `tsym` and spot price. `Qty = UserLots * IndexLotSize`.
    - [x] Implement robust error reporting in `StrategyPage`

- **Digital Signing**:
    - Generated a release keystore (`upload-keystore.jks`) in `android/app/`.
    - Created `key.properties` to store signing credentials.
    - Updated `build.gradle.kts` to load these properties and use them for the `release` build type.

### [Implemented] Order Confirmation Dialogs

### Goal
Prevent accidental orders by requiring user confirmation before placing new orders or closing existing positions.

### 1. Reusable Component: `GlassConfirmationDialog`
- **File**: `lib/widgets/glass_widgets.dart`
- **Design**:
    - Extends `Dialog` with a custom `GlassCard` background.
    - **Header**: "Confirm Order" (with Warning Icon).
    - **Content**: List of items to confirm (Scrip Name, Type, Price/Market).
    - **Actions**: "Cancel" (Outlined) and "Confirm" (Neon Button).

### 2. Integration Points
- **Strategy Page**:
    - **Trigger**: "INITIATE SEQUENCE" button.
    - **Data**: List of selected strikes (Symbol, Action: BUY, Price: Market).
- **Positions Page**:
    - **Trigger**: "Close" button (Individual)
        - **Data**: Single scrip (Symbol, Action: SELL/BUY based on net qty, Price: Market)
    - **Trigger**: "EXIT ALL RUNNING POSITIONS" button (Portfolio)
        - **Data**: All open positions.
        - **Improvement**: Checks for empty positions before showing dialog.
- **Order Book**:
    - Enhanced visibility of order entry time.
