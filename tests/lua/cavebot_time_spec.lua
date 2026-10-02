-- Reuse the Explorer's offline UI fixture for quota-only regressions.
CAVEBOT_TIMER_ONLY=true
dofile('tests/lua/auto_explorer_v2_spec.lua')
CAVEBOT_TIMER_ONLY=nil
