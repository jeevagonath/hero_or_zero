# Shoonya API Service Extension

Extend the `ApiService` to include missing core functionalities required for trading, based on the Shoonya API documentation.

## Proposed Changes

### [ApiService Extension]

#### [MODIFY] [main.dart](file:///d:/FlutterApps/hero_or_zero/lib/main.dart)

- Initialize `ApiService` and load token from storage.
- Check if token exists; if so, navigate to `MainScreen`.
- If no token, show `LoginPage`.

#### [MODIFY] [dashboard_placeholder_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/dashboard_placeholder_page.dart)

- Capture `o` (Open) price from WebSocket ticks.
- Calculate `absChange` as `LTP - Open`.
- Calculate `percentageChange` as `(absChange / Open) * 100`.
- Update `_buildIndexCard` to display these calculated values correctly.

#### [MODIFY] [websocket_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/websocket_service.dart)

- Implement `_reconnect` logic with exponential backoff.
- Add periodic heartbeat (ping) to keep connection alive.
- Maintain a list of active subscriptions to re-subscribe upon reconnection.

#### [NEW] [settings_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/settings_page.dart)

- Configuration for NIFTY/SENSEX trading days.
- Configuration for NIFTY/SENSEX lot sizes.
- Persistent storage using `StorageService`.

#### [MODIFY] [strategy_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/strategy_page.dart)

- Convert to `StatefulWidget`.
- Monitor time and capture spot price at 1:15 PM on designated days.
- Logic to find OTM/ATM strikes (+/- 50 for NIFTY, +/- 100 for SENSEX).
- Display selectable strikes.
- Execute market buy orders via `ApiService.placeOrder`.

#### [MODIFY] [storage_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/storage_service.dart)

- Add helpers to save/load strategy configuration and state.

#### [MODIFY] [user_details_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/user_details_page.dart)

- Add a "Settings" link/button.

### Strategy Live Prices Integration

#### [MODIFY] [strategy_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/strategy_page.dart)

- **Contract Resolution**: After spot capture, use `ApiService.searchScrip` to find the exact `token` and `tsym` for the generated strikes.
- **WebSocket Subscription**:
    - Manage a list of active strategy subscriptions.
    - Call `WebSocketService.subscribeTouchline` for each confirmed contract.
- **Price Updates**:
    - Listen to `WebSocketService.messageStream`.
    - Update the `_strikes` list with the latest `lp` (Last Traded Price).
- **UI Enhancement**:
    - Display the live LTP next to each strike in the selection list.
    - Show "Loading..." or "Searching..." while contracts are being resolved.

### 11. User Logout

#### [MODIFY] [api_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/api_service.dart)
- Add `logout()` to clear `_userToken` and `_userId`.

#### [MODIFY] [user_details_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/user_details_page.dart)
- Add a "Logout" button at the bottom of the page.
- Implement logic to clear storage and navigate to `LoginPage`.

- Ensure `/login` route is available if needed, though simple `PushReplacement` usually suffices.

### 12. Persistent Developer Settings

#### [MODIFY] [storage_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/storage_service.dart)
- Add constants and methods for saving/loading `vendorCode`, `apiKey`, and `imei`.
- Ensure these are NOT included in the `clearAll()` method used for logout.

#### [NEW] [developer_settings_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/developer_settings_page.dart)
- UI with text fields for Vendor Code, API Key, and IMEI.
- Save to `StorageService`.

#### [MODIFY] [login_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/login_page.dart)
- Add a settings icon button in the header.
- On initialization, load developer configs.
- Use stored configs for the `quickAuth` call instead of `ApiConstants`.

#### [MODIFY] [main.dart](file:///d:/FlutterApps/hero_or_zero/lib/main.dart)
- Register `/developer-settings` route.

### 13. Positions Page and Global P&L

#### [MODIFY] [api_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/api_service.dart)
- Update `getPositionBook` to include `actid` in `jData`.

#### [NEW] [pnl_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/pnl_service.dart)
- Singleton service to manage live P&L.
- Fetches initial positions.
- Subscribes to tokens via `WebSocketService`.
- Calculates realized and unrealized P&L: `urmtom = netqty * (ws_lp - netavgprc) * prcftr`.
- Provides a `ValueNotifier` or `Stream` for global P&L updates.

#### [MODIFY] [main_screen.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/main_screen.dart)
- Add a persistent header/top bar to display Total P&L across all views.
- Listen to `PnLService` for updates.

#### [MODIFY] [order_book_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/order_book_page.dart)
- Fetch and display session order history.
- Handle "no data" responses gracefully.

### 15. Trade Book Page

#### [MODIFY] [api_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/api_service.dart)
- Update `getTradeBook` to include `actid` in `jData`.

#### [MODIFY] [trade_book_page.dart](file:///d:/FlutterApps/hero_or_zero/lib/screens/trade_book_page.dart)
- Convert to `StatefulWidget`.
- Fetch data on initialization.
- Display a list of executed trades with:
    - Symbol and Transaction Type (B/S)
    - Fill Quantity and Fill Price
    - Fill Time
    - Product and Exchange info.
- Handle "no data" response by showing an empty state.

## Verification Plan

### Manual Verification
- **Header P&L**: Verify P&L is visible on all dashboard tabs.
- **Positions List**: Verify all open positions are listed with correct quantity and avg price.
- **Live Updates**: Cross-verify P&L changes with a real trading terminal if possible or simulate price movements.
- **WebSocket Subscription**: Ensure all tokens from the position book are subscribed on entry and unsubscribed when appropriate.
- **Login Flow**: Verify `quickAuth` still works and saves the `usertoken`.
- **Market Data**: Verify `searchScrip` and `getQuote` return correct data.
- **Order Placement**: (Cautious) Test with a small quantity on a low-value stock if possible, or verify the request format against the documentation.
- **Data Retrieval**: Verify `getPositionBook` and `getTradeBook` return valid JSON structures as per docs.
- **WebSocket**: Verify connection can be established and ticks are received.
