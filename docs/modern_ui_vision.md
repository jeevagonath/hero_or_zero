# Modernized UI/UX Design Language

To create a "WOW" factor, we will implement a **Dark Glassmorphism** aesthetic. This direction combines deep, rich backgrounds with semi-transparent, "frosted" elements to create depth and a premium feel.

## Design Principles

### 1. Vision & Aesthetic
- **Core Theme**: Deep Charcoal (#0F1216) background.
- **Glassmorphism**: Use `BackdropFilter` with `ImageFilter.blur` to create frosted glass cards.
- **Vibrant Accents**: 
  - **Primary**: Electric Blue (#4D96FF) for buttons and active states.
  - **Success**: Emerald Green (#00D97E) with subtle glows.
  - **Danger**: Sunset Orange/Red (#FF5F5F).
- **Typography**: Clean, geometric sans-serif (Inter or Google Fonts Outfit).

### 2. Page-Specific Enhancements

#### Dashboard (Watchlist)
- **Before**: Simple list with text.
- **After**: Vertical cards with semi-transparent backgrounds. Live prices will "flicker" with a subtle color pulse when they change.
- **Charts**: Add subtle mini-sparklines next to scrips for daily trend visualization.

#### Strategy Page (The Hub)
- **Before**: Standard cards and buttons.
- **After**:
  - **Status Halo**: The "Execution State" will have a soft, pulsing ring (glow) around it.
  - **Strike Grid**: Calls and Puts organized in a sleek grid with frosted backgrounds.
  - **Glass Buttons**: Main action buttons (Place Order) will have high-contrast gradients and soft shadows.

#### Positions & PnL
- **Before**: Standard account-style rows.
- **After**: Large, bold "Total P&L" header with a soft glow reflecting the current profit/loss status. (Green glow for profit, Red for loss).

### 3. Micro-Interactions
- **Haptic Feedback**: Light vibration on successful actions.
- **Smooth Transitions**: Using `AnimatedContainer` and `PageTransition` for fluid movement.
- **Loading States**: Shimmer effects on glass cards while data is fetching.

---

## Implementation Roadmap
1. **Core Theme Update**: Define the new global theme data in `main.dart`.
2. **Component Library**: Create reusable "GlassCard" and "NeonButton" widgets.
3. **Dashboard Refresh**: Apply the new style to the watchlist.
4. **Strategy Hub Overhaul**: Complete redesign of the strategy and exit plan cards.
5. **Polishing**: Add animations and refined typography.
