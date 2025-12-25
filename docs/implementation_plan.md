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
    - Change `_buildSearchResultsOverlay` to a height-limited `ListView` embedded directly in the main `Column` when searching, so it doesn't float over the text box.
- **Backend Sync**:
    - When adding a scrip: call `addMultiScripsToMW` then subscribe to WS.
    - When deleting a scrip: call `deleteMultiMWScrips` then unsubscribe from WS.
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

### Robust SENSEX Resolution
- **SENSEX Strike Step**: Use a **100-point step** for SENSEX (instead of 50).
- **Search Robustness**:
    - Try multiple search patterns (e.g., `targetIndex + strike + " CE"`, `targetIndex + strike + "CE"`, etc.).
    - For BSE (SENSEX), the symbols can be variants like `SENSEX85500CE` or `SENSEX 85500 CE`.
- **Diagnostic Logging**: Use `debugPrint` for every step of the resolution process to aid troubleshooting.

## Verification Plan

### Manual Verification
- **Global Trigger**:
    - Set the strategy time to 1 minute in the future.
    - Switch to the "Dashboard" or "Positions" tab.
    - Wait until the time passes, then switch to "Strategy".
    - Verify that the strikes are already resolved and prices are updating.
- **Minimized App**:
    - (For Android) Set the time, minimize the app, wait 1 minute.
    - Re-open the app and verify the strategy triggered while it was minimized.
- **Trailing SL**:
    - Open a position and verify TSL updates in `PnLService` logs even when on the Dashboard.
