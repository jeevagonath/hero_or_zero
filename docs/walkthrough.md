# Shoonya API Implementation Walkthrough

I have extended the Shoonya API integration to support core trading functionalities and real-time market data.

## Changes Made

### 1. API Constants Updated
Updated [constants.dart](file:///d:/FlutterApps/hero_or_zero/lib/core/constants.dart) with new endpoints for:
- Order Placement
- Position Book
- Trade Book
- Order Book
- Holdings
- WebSocket URL

### 2. ApiService Extended
Added the following methods to [api_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/api_service.dart):
- `placeOrder`: Supports Limit, Market, and SL orders.
- `getPositionBook`: Retrieves all current positions.
- `getTradeBook`: Retrieves today's executed trades.
- `getOrderBook`: Retrieves today's order history.
- `getHoldings`: Retrieves equity holdings.

### 3. WebSocket Service Implemented
Created [websocket_service.dart](file:///d:/FlutterApps/hero_or_zero/lib/services/websocket_service.dart) to handle real-time data:
- Connection and authentication with Shoonya servers.
- Streaming of messages via a broadcast `messageStream`.
- Methods to `subscribeTouchline` and `unsubscribeTouchline` for live price updates.

### 4. Dependencies Added
Updated [pubspec.yaml](file:///d:/FlutterApps/hero_or_zero/pubspec.yaml) to include `web_socket_channel`.

### 5. Auto-Login & Persistence
- Updated [StorageService](file:///d:/FlutterApps/hero_or_zero/lib/services/storage_service.dart) to store `usertoken` and `uid`.
- Modified [main.dart](file:///d:/FlutterApps/hero_or_zero/lib/main.dart) to attempt auto-login on startup.
- If a valid session exists, the app navigates directly to the Dashboard.

### 6. Live Dashboard & Price Refinement
- Updated [DashboardPlaceholderPage](file:///d:/FlutterApps/hero_or_zero/lib/screens/dashboard_placeholder_page.dart) to use `WebSocketService`.
- **Refined Calculation**: Prices now show the change relative to the **Open Price** (`LTP - Open`) instead of previous close, as requested.
- Added initial quote fetching to ensure accurate daily stats immediately upon loading.
- Added a "LIVE" indicator and updated the UI layout.

### 7. Robust WebSocket Connectivity
- **Auto-Reconnect**: The [WebSocketService](file:///d:/FlutterApps/hero_or_zero/lib/services/websocket_service.dart) now automatically reconnects if the connection is lost, using an exponential backoff strategy (up to 10 attempts).
- **Heartbeat Logic**: Sends a heartbeat signal ('h' frame) every 30 seconds to the Shoonya servers to keep the connection alive.
- **Persistent Subscriptions**: Automatically tracks and re-subscribes to all active tokens (like NIFTY, SENSEX, and your Watchlist) whenever the connection is re-established.

### 8. Scrip Search & Live Watchlist
- **Search with Debouncing**: Added a search bar with a 500ms debounce to optimize API calls while typing.
- **Floating Results**: Search results appear in an overlay for quick selection without navigating away.
- **Live Watchlist**: Selected scrips are added to a watchlist below the indices.
- **WebSocket Integration**: New watchlist items are automatically subscribed to the WebSocket for real-time LTP and day-change updates.

### 9. Automated Trading Strategy
- **Spot Capture**: Real-time spot price capture at **1:15 PM** for NIFTY (Tuesdays) and SENSEX (Thursdays).
- **Strike Selection**: Automatically calculates nearest 50 (NIFTY) or 100 (SENSEX) OTM strikes (2 PE, 1 ATM, 2 CE).
- **Settings Page**: New [SettingsPage](file:///d:/FlutterApps/hero_or_zero/lib/screens/settings_page.dart) to configure trading days and lot sizes.
- **Persistence**: Strategy configurations are saved locally via [StorageService](file:///d:/FlutterApps/hero_or_zero/lib/services/storage_service.dart).

### 10. Live Strategy Prices
- **Auto-Contract Discovery**: The system automatically searches for the exact tradable contracts (e.g., NIFTY 26650 PE) based on the 1:15 PM spot price.
- **WebSocket Streaming**: All identified strikes are immediately subscribed to the WebSocket for live price updates.
- **Real-time UI**: The "Select Strike Prices" list now shows the current market price for each option alongside its name.
- **Cleanup**: Automatically unsubscribes from these strikes when navigating away or capturing a new spot price.

### 11. Secure Logout
- **Wipe Session**: Added a **LOGOUT** button in [UserDetailsPage](file:///d:/FlutterApps/hero_or_zero/lib/screens/user_details_page.dart) that clears `usertoken` and `uid`.
- **State Reset**: `ApiService` clears its memory cache to prevent stale data usage.
- **Redirection**: Automatically navigates back to the Login screen, clearing the navigation history.

### 12. Persistent Developer Settings
- **Flexible Configuration**: Added a settings icon to the Login page for configuring `vendorCode`, `apiKey`, and `imei`.
- **True Persistence**: These settings are stored separately and are **never deleted** during logout, ensuring the app remains personalized for each user.
- **Dynamic Auth**: The app now uses these stored values for login instead of hardcoded constants, making it multi-user compatible.

### 13. Live Positions & Global P&L
- **Real-time M2M**: Implemented a global `PnLService` that calculates Total P&L in real-time using `urmtom = netqty * (lp - avgprc) * prcftr`.
- **Global Header**: Every screen now features a P&L display in the header, keeping your performance visible at all times.
- **Detailed Positions Page**: Launched a dedicated [PositionsPage](file:///d:/FlutterApps/hero_or_zero/lib/screens/positions_page.dart) showing realized/unrealized P&L, live LTP, and position specifics (Qty, Avg Price).
- **WebSocket Integration**: Automatically subscribes to all open position tokens for low-latency price updates.

### 14. Detailed Order Book
- **Session History**: Added a dedicated [OrderBookPage](file:///d:/FlutterApps/hero_or_zero/lib/screens/order_book_page.dart) to view all orders placed during the session.
- **Smart Status Visibility**: Orders are color-coded based on their execution status (Complete, Rejected, Pending).
- **Comprehensive Data**: Each order displays its Symbol, Transaction Type (Buy/Sell), Quantity (Filled/Total), Price, and Avg. Execution Price.
- **Rejection Details**: Rejection reasons are clearly shown for failed orders to help with quick debugging.

### 15. Real-time Trade Book
- **Execution History**: Added a dedicated [TradeBookPage](file:///d:/FlutterApps/hero_or_zero/lib/screens/trade_book_page.dart) to track every fill in the current session.
- **Fill Precision**: Shows the exact Fill Price, Fill Quantity, and Fill Time for every executed leg.
- **Clean Empty States**: Handles the "no data" response gracefully, showing a clear message when no trades have been made yet.

### 16. Login Experience Enhancements
- **Auto-Formatting**: User ID now automatically capitalizes and trims whitespace, preventing common entry errors.
- **Secure Input**: TOTP field is now obscured and limited to numeric input, improving security and speed.

## Verification Steps
- [x] **Auto-Login**: Verified navigation flow based on token availability.
- [x] **WebSocket Connectivity**: Heartbeats and re-subscriptions are working.
- [x] **Search & Watchlist**: Live prices and debouncing verified.
- [x] **Strategy Logic**: Verified strike calculation intervals (+/- 50 for NIFTY).
- [x] **Settings**: Verified that changes to lot size and days are persisted.
- [x] **UI Snapshot**: Alignment with design verified.

> [!NOTE]
> For WebSocket usage, ensure you call `connect()` with the `usertoken` obtained from `quickAuth`.
