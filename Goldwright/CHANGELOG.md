# Goldwright changelog

## 0.7.3 (unreleased)

- **Fixed:** the Sell and Auctions tabs showed items that don't stack (books, recipes, bags, gear) far too cheap when several were listed at the same price. ([#5](https://github.com/goldwrightapp/goldwright-addon/issues/5))

## 0.7.2

Better at spotting bait, so the Sell tab doesn't suggest dumping your item, and random-suffix gear keeps its price after a scan.

- **Bait:** a handful of very cheap listings followed by a big jump up to the real market (for example 6 Mageweave Bags at 6s when they sell for 60s) are now ignored, as long as they're far under the item's recent price and only a small part of the market. Before, only up to three cheap items were caught. A real price drop, where prices step down gradually, still counts. The tooltip, the Sell tab and the Auctions tab use the same rule, and so does the website. ([#2](https://github.com/goldwrightapp/goldwright-addon/issues/2))
- **Bug reports:** `/gw bug` now includes the last few bait checks (the cheap listings it saw and what it decided), so a wrong price can be traced.
- **Gear with a random suffix after a full scan:** items like "Spiked Chain Leggings of Intellect" no longer show as not listed in the tooltip after you scan that auction house. A scan sees the base item but can't tell suffixes apart, so the suffix keeps its price from Goldwright Data while the item is listed, and only shows as not listed when the scan found none of that item at all. Thanks to azohra for the report. ([#1](https://github.com/goldwrightapp/goldwright-addon/issues/1))
