# Hero or Zero - Strategy & Exit Logic Reference

**Last Updated:** 2025-12-25
**Version:** 1.0

This document serves as the primary technical reference for the **Hero or Zero** trading application. It details the exact logic used for strike selection, trade execution, and automated exit management as implemented in the codebase.

---

## 1. Strategy Overview

The application implements a "Hero or Zero" index option buying strategy that targets **Out-of-the-Money (OTM)** strikes on NIFTY 50 and SENSEX. The strategy is time-based and systematically captures the spot price to determine strike targets.

### 1.1 Core Trigger Logic
*   **Controller:** `StrategyService`
*   **Trigger Condition:** The strategy execution begins automatically when the system clock matches or exceeds the **Strategy Time** configured in Settings (Default: **13:15**).
*   **Frequency:** Checks once per second.
*   **Daily constraint:** Executes only on the configured day for the index (e.g., Tuesday for NIFTY, Friday for SENSEX).

---

## 2. Strike Selection Logic

The application calculates target strikes dynamically based on the **Spot Price** captured at the trigger time. It targets 2 levels of OTM strikes for both Call (CE) and Put (PE) options.

### 2.1 Parameters
| Index | Step Size | Symbol Format | Exchange | Token Source |
| :--- | :--- | :--- | :--- | :--- |
| **NIFTY** | 50 | `NIFTY` | NSE / NFO | 26000 (Index Token) |
| **SENSEX** | 100 | `SENSEX` | BSE / BFO | 1 (Index Token) |

### 2.2 Calculation Logic
The logic identifies the **First OTM** strike and then moves outward.

*   **CE Base (Call Entry):**
    `Floor(Spot Price / Step Size) * Step Size + Step Size`
    *(Example: Spot 24,120 / 50 = 482.4 -> Floor(482) * 50 = 24,100 + 50 = **24,150**)*
    
*   **PE Base (Put Entry):**
    `Ceil(Spot Price / Step Size) * Step Size - Step Size`
    *(Example: Spot 24,120 / 50 = 482.4 -> Ceil(483) * 50 = 24,150 - 50 = **24,100**)*

### 2.3 Target Set (The Quad)
The system aims to resolve and display 4 specific contracts:

1.  **CE 1 (Near OTM):** `CE Base`
2.  **CE 2 (Far OTM):** `CE Base + Step Size`
3.  **PE 1 (Near OTM):** `PE Base`
4.  **PE 2 (Far OTM):** `PE Base - Step Size`

### 2.4 Example Scenarios

#### Scenario A: NIFTY (Step 50)
*   **Spot Price Captured:** 24,120
*   **Logic:**
    *   CE Base: Next multiple of 50 > 24,120 -> **24,150**
    *   PE Base: Previous multiple of 50 < 24,120 -> **24,100**
*   **Resolved Strikes:**
    1.  NIFTY **24,150** CE
    2.  NIFTY **24,200** CE (24,150 + 50)
    3.  NIFTY **24,100** PE
    4.  NIFTY **24,050** PE (24,100 - 50)

#### Scenario B: SENSEX (Step 100)
*   **Spot Price Captured:** 85,150
*   **Logic:**
    *   CE Base: Next multiple of 100 > 85,150 -> **85,200**
    *   PE Base: Previous multiple of 100 < 85,150 -> **85,100**
*   **Resolved Strikes:**
    1.  SENSEX **85,200** CE
    2.  SENSEX **85,300** CE (85,200 + 100)
    3.  SENSEX **85,100** PE
    4.  SENSEX **85,000** PE (85,100 - 100)

---

## 3. Trade Execution Flow

### 3.1 Lot Size & Quantity
*   **Source of Truth:** The Lot Size (`ls`) is fetched dynamically from the **Option Chain** of the first resolved strike using the capture price. This ensures accuracy even if exchange mandates change.
*   **User Input:** The user defines the number of **Lots** in Settings (e.g., 2 Lots).
*   **Calculation:** `Quantity = User Lots * Index Lot Size`
    *(Example: 2 Lots * 75 (Nifty LS) = **150 Qty**)*

### 3.2 Order Placement (`ApiService`)
All orders are executed with the following parameters:
*   **Product Type:** `M` (NRML/Margin) - *Standard for carry-forward or intraday*.
*   **Order Type:** `MKT` (Market) - *Ensures immediate execution*.
*   **Validity:** `DAY`.
*   **Execution:** Sequential execution of all selected strikes in the Strategy UI.

---

## 4. Exit Plan & Risk Management

The application features a robust, automated exit mechanism governed by the `PnLService`.

### 4.1 Trailing Stop-Loss (TSL)
The TSL is calculated on the **Net Portfolio P&L** (Total of all running positions), not on individual scrips.

*   **Activation Threshold:**
    The TSL logic activates **ONLY** when Total Profit reaches:
    `200 INR * Total Lots`
    *(Example: 2 Lots -> Activates at +₹400 Profit)*

*   **Trailing Gap:**
    The distance maintained from the Peak Profit:
    `150 INR * Total Lots`
    *(Example: 2 Lots -> Gap is ₹300)*

*   **Logic Flow:**
    1.  **Monitor:** Check P&L on every tick/update.
    2.  **Activate:** If `Profit >= Threshold` and TSL is not set, set `TSL = Current Profit - Gap`.
    3.  **Trail:** If `Profit > Peak Profit`, update `Peak Profit` -> `TSL = New Peak - Gap`.
    4.  **Trigger:** If `Profit <= TSL`, initiate **SQUARE OFF ALL**.

#### TSL Example (2 Lots - Nifty)
*   **Params:** Threshold = ₹400, Gap = ₹300.
1.  **Profit +₹200:** TSL Inactive.
2.  **Profit +₹400:** TSL Activated at ₹100 (400 - 300).
3.  **Profit +₹1000:** Peak is ₹1000. TSL moves to ₹700 (1000 - 300).
4.  **Profit drops to ₹750:** TSL holds at ₹700. Position remains open.
5.  **Profit drops to ₹700:** **EXIT TRIGGERED**. All positions closed.

### 4.2 Hard Stop (Time-Based)
*   **Condition:** strict check for `Current Time == Exit Time`.
*   **Configuration:** Configurable in Settings (Default: **15:00** / 3:00 PM).
*   **Action:** Forces `squareOffAll()` regardless of P&L.

### 4.3 Manual Exit
*   **Close All:** A prominent "EXIT ALL" button on the UI allows immediate square-off of the entire portfolio.
*   **Individual Close:** Users can close specific legs from the Positions tab.

---

## 5. Negative Flows & Validation

### 5.1 Spot Capture Failures
*   **Scenario:** API fails to return a quote or returns empty data.
*   **Handling:** The system retries the capture process **5 times** with a 10-second delay between attempts.
*   **Feedback:** UI displays specific error messages (e.g., "Network Error", "No 'lp' in response").

### 5.2 Strike Resolution Failures
*   **Scenario:** Calculated strike (e.g., SENSEX 85200 CE) is not found in the search API.
*   **Handling:**
    *   Tries 3 different search patterns: `"SENSEX 85200 CE"`, `"SENSEX85200 CE"`, `"SENSEX 85200"`.
    *   If still not found, that specific strike is skipped, but others in the Quad are processed.
    *   Error shown: "Only resolved X/4 strikes".

### 5.3 Order Validation
*   **Scenario:** Zero Quantity or Missing User ID.
*   **Handling:**
    *   `placeOrder` is blocked if `User ID` is null.
    *   `placeOrder` blocks if `selectedStrikes` list is empty.
    *   Quantity is strictly validated (must be > 0).

### 5.4 Session Expiry
*   **Scenario:** User token expires mid-trade.
*   **Handling:** API calls return `Not_Ok` or HTTP errors. The app prompts the user to re-login, but active TSL monitoring requires a valid session to execute exits. (Critical: Ensure app remains logged in during strategy hours).
