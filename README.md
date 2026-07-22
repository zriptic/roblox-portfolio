# Grady — Roblox Scripter

Server-authoritative gameplay systems, data that never corrupts, and the analytics to prove what's working. I script in Luau and build the backend tooling around it when Roblox's own tools are too slow.

---

## Featured Projects

### 🟢 Roblox Live Analytics — full-stack, in production
Roblox's official analytics lag 24–48 hours. I built my own real-time pipeline so I can watch sessions, CCU, funnels, and Robux live while a game is being played.

- **Luau SDK** ([samples/Analytics.lua](samples/Analytics.lua)) — a single drop-in ModuleScript: batched HTTP event queue with retry, session tracking, marketplace purchase hooks, onboarding + repeatable funnels that mirror to Roblox's `AnalyticsService` with one call, and `ProcessReceipt` ground truth.
- **Backend** — Node.js + Fastify ingesting batched events into Postgres, deployed on Railway.
- **Dashboard** — live CCU, playtime, monetization, and funnel visualizations, auto-refreshing every 5 seconds, multi-game from one deployment.

### 💥 BOOM BASE (Build a City and Nuke)
Plot-based build-and-destroy game. 16-pad plot system with template-plot cloning, roll stations, and strict server-side ownership validation — clients request, the server decides. The plot architecture pattern is in [samples/PlotService.lua](samples/PlotService.lua).

### 🏛️ Era Rebirth
Six-era progression tycoon (Stone → Space) with ~193 custom-built assets. Era gating, droppers, and upgrade paths driven by data — one config table per era, zero copy-pasted scripts.

### 🥷 Ninja Simulator
Earlier simulator project — training zones, pet multipliers, rebirth loops. Where I learned the hard lessons about DataStore corruption that led me to ProfileService.

---

## Code Samples

Every file in [`samples/`](samples/) is written the way I write production code: OOP modules, clean public APIs, no redundant validation, no RemoteEvent sprawl.

| File | What it shows |
|---|---|
| [Analytics.lua](samples/Analytics.lua) | **Real shipped code.** HTTP batching with retry, service hooks, Studio guards, graceful `BindToClose` flush |
| [DataService.lua](samples/DataService.lua) | ProfileService wrapper — session-locked player data, safe release, leaderstats binding, in-game data API |
| [PlotService.lua](samples/PlotService.lua) | Server-authoritative plot claiming and placement — template cloning, ownership checks, exploit-proof by design |
| [ObjectPool.lua](samples/ObjectPool.lua) | Generic instance pooling for high-churn effects (debris, casings, hit VFX) without `Instance.new` spam |

---

## How I work

- **Server owns the truth.** Clients render and request; every state change is validated where exploiters can't reach it.
- **ProfileService for anything that must not be lost.** Session locking beats DataStore band-aids.
- **Data-driven systems.** New era, new item, new plot type = new config entry, not new script.
- **Measure, don't guess.** If a mechanic matters, it gets a funnel step. That's why I built my own analytics stack.

## Toolbox

`Luau` · `ProfileService` · `AnalyticsService` · `HttpService` · `Roblox Studio` · `Node.js` · `Fastify` · `PostgreSQL` · `Railway` · `Git`

---

*Open to scripting commissions and team work — DM me here on GitHub.*
