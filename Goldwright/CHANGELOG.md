# Goldwright changelog

## 0.7.1

A clearer tooltip: two price names instead of five, money lined up in one column, and Shift only adds lines below.

- **Tooltip:** the first line is **Goldwright · Min price**, the cheapest real listing (bait skipped), with no blank line or separate header above it. Then how it sells in plain words ("Sells fast ~1,960 a day · price -5% this week"), a buy or sell hint when the min price is far from the average, and each other auction house on its own line. Every amount of money sits alone on the right, and a one-digit coin after a bigger one takes two digits of room, so the coins line up and you can compare prices straight down.
- **Holding Shift** adds lines below and never moves the ones already there: **Avg price (7 days)** and **(30 days)**, bait listings that were skipped, a vendor deal, your own sales in one line ("You sold 28, last at 99c", plus "9 of yours came back unsold" only when some did), how many are listed at each house, and where the prices come from ("From your scan 25 min ago").
- **Gone from the tooltip:** Market value, the normal price, the 30-day lowest and highest day, and the stack value. Market value still sets prices on the Sell tab, in shopping lists and in the signals.
- **Vendor:** when a vendor pays more than the auction house would net you, an orange line says so without holding Shift.
- **Tooltip settings:** "Other houses" is now two settings: **Blackwater prices** (on) and the other faction's prices (**Horde prices** for Alliance, **Alliance prices** for Horde), off by default because you can't mail items to the other faction. If you had turned "Other houses" off, Blackwater stays off. The "Market value" setting is gone with its line; "Now" is now **Min price**, "Normal price" is now **Average prices**, and "Trend and sell rate" is now **Sell rate and price trend**.
