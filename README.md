# Grady — Roblox Scripter

**6+ years in Luau · 166M+ combined visits across shipped games · 30K+ peak CCU · 16 y/o**

I write server-authoritative gameplay systems, data that never corrupts, and the analytics to prove what's working. Currently **open to part-time studio positions (30–40 hrs/week)**.

📬 **Discord** `zriptic` · **Twitter/X** [@gradylau7](https://twitter.com/gradylau7) · **Roblox** [Zriptics](https://www.roblox.com/users/397380209/profile) · **GitHub** [@zriptic](https://github.com/zriptic)

---

## Shipped Work — Inter

Update and feature scripting across the studio's live portfolio:

| Game | Visits |
|---|---:|
| [Burgerz 🍔](https://www.roblox.com/games/99817148924004/Burgerz) | 62.0M |
| [Rob the place](https://www.roblox.com/games/17483941801/Rob-the-place) | 60.5M |
| [The YouTuber Experience 📷](https://www.roblox.com/games/16070422076/The-YouTuber-Experience) | 10.6M |
| [Midnight FNAF](https://www.roblox.com/games/112299523957068/Midnight-FNAF) | 8.8M |
| [Anime Haven Simulator](https://www.roblox.com/games/17857913030/Anime-Haven-Simulator) | 6.5M |
| [Cart Buddies](https://www.roblox.com/games/17332139796/Cart-Buddies) | 5.4M |
| [The Donut Shop Experience 🍩](https://www.roblox.com/games/16469668703/The-Donut-Shop-Experience) | 4.1M |
| [Bubble Blowing Simulator](https://www.roblox.com/games/13126775213/Bubble-Blowing-Simulator) | 2.5M |
| [The Diner Experience ☕](https://www.roblox.com/games/16117157623/The-Diner-Experience) | 2.5M |
| [The Boba Shop Experience](https://www.roblox.com/games/15910958658/The-Boba-Shop-Experience) | 2.3M |
| [The Subway Experience](https://www.roblox.com/games/16218949773/The-Subway-Experience) | 0.9M |

*Visit counts as of July 2026.*

---

## Personal Projects

### 💸 Become an Scammer Billionaire — live, solo
[Play it here](https://www.roblox.com/games/80315788625581/Become-an-Scammer-Billionaire) — designed, scripted, and shipped solo. **60K+ visits** since launching June 2026 and still climbing.

### 🟢 Roblox Live Analytics — full-stack, in production
Roblox's official analytics lag 24–48 hours. I built my own real-time pipeline so I can watch sessions, CCU, funnels, and Robux live while a game is being played.

- **Luau SDK** ([samples/Analytics.lua](samples/Analytics.lua)) — a single drop-in ModuleScript: batched HTTP event queue with retry, session tracking, marketplace purchase hooks, onboarding + repeatable funnels that mirror to Roblox's `AnalyticsService` with one call, and `ProcessReceipt` ground truth.
- **Backend** — Node.js + Fastify ingesting batched events into Postgres, deployed on Railway.
- **Dashboard** — live CCU, playtime, monetization, and funnel visualizations, auto-refreshing every 5 seconds, multi-game from one deployment.

### 💥 BOOM BASE (Build a City and Nuke)
Plot-based build-and-destroy game, in development. 16-pad plot system with template-plot cloning, roll stations, and strict server-side ownership validation — clients request, the server decides. The plot architecture pattern is in [samples/PlotService.lua](samples/PlotService.lua).

### 🏛️ Era Rebirth
Six-era progression tycoon (Stone → Space). Era gating, droppers, and upgrade paths driven by data — one config table per era, zero copy-pasted scripts.

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

*Looking for a part-time scripter? **Discord: `zriptic`***
