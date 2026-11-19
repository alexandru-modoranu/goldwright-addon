# Goldwright changelog

## 0.5.1

Bug fix.

- Fixed an error ("attempt to index local 'msg' (a secret string value…)") that could appear when the game sent a protected chat message, for example a sale message during combat. Goldwright now skips messages the game doesn't let add-ons read. Your sales record isn't affected: it comes from your auction mail.
