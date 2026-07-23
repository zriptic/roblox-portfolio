<div align="center">

# Grady

Roblox scripter. 6 years of Luau, 16 years old.

Games I've scripted on have passed **166 million visits**, with peaks over **30k concurrent players**.

[![Twitter](https://img.shields.io/badge/twitter-gradylau7-1DA1F2?logo=x&logoColor=white)](https://twitter.com/gradylau7)
[![Roblox](https://img.shields.io/badge/roblox-Zriptics-black?logo=roblox&logoColor=white)](https://www.roblox.com/users/397380209/profile)
![Discord](https://img.shields.io/badge/discord-zriptic-5865F2?logo=discord&logoColor=white)

Currently open to part-time studio work, 30-40 hrs/week. Discord is the fastest way to reach me.

</div>

## Shipped work

Update and feature scripting on live games. Some titles I've worked on:

| Game | Visits |
|---|---:|
| [Burgerz](https://www.roblox.com/games/99817148924004/Burgerz) | 62.0M |
| [Rob the place](https://www.roblox.com/games/17483941801/Rob-the-place) | 60.5M |
| [The YouTuber Experience](https://www.roblox.com/games/16070422076/The-YouTuber-Experience) | 10.6M |
| [Midnight FNAF](https://www.roblox.com/games/112299523957068/Midnight-FNAF) | 8.8M |
| [Anime Haven Simulator](https://www.roblox.com/games/17857913030/Anime-Haven-Simulator) | 6.5M |
| [Cart Buddies](https://www.roblox.com/games/17332139796/Cart-Buddies) | 5.4M |
| [The Donut Shop Experience](https://www.roblox.com/games/16469668703/The-Donut-Shop-Experience) | 4.1M |
| [Bubble Blowing Simulator](https://www.roblox.com/games/13126775213/Bubble-Blowing-Simulator) | 2.5M |
| [The Diner Experience](https://www.roblox.com/games/16117157623/The-Diner-Experience) | 2.5M |
| [The Boba Shop Experience](https://www.roblox.com/games/15910958658/The-Boba-Shop-Experience) | 2.3M |
| [The Subway Experience](https://www.roblox.com/games/16218949773/The-Subway-Experience) | 0.9M |

Visit counts pulled July 2026.

## My games

**[Become an Scammer Billionaire](https://www.roblox.com/games/80315788625581/Become-an-Scammer-Billionaire)** — built completely solo, launched June 2026. Honestly? It flopped. But go play it — the game itself is well made and polished, and it's the best public look at how I script. Every flop teaches you something the wins don't.

## Code samples

The code in [samples/](samples/) is how I actually write, not cleaned up for show:

- [Analytics.lua](samples/Analytics.lua) — the real SDK from my analytics platform. HTTP batching with retry, marketplace hooks, Studio guards, flush on shutdown
- [DataService.lua](samples/DataService.lua) — ProfileService wrapper. Session-locked data, safe release, atomic spending so remotes can't dupe currency
- [PlotService.lua](samples/PlotService.lua) — plot claiming and structure placement with everything validated server-side. The client asks, the server decides
- [ObjectPool.lua](samples/ObjectPool.lua) — instance pooling for high-churn effects instead of hammering Instance.new

## How I build

Server owns the truth, always. ProfileService for anything that can't be lost. Systems are data-driven so content doesn't mean new code. And if a mechanic matters, it gets a funnel step — I'd rather look at numbers than guess.

Tools I use day to day: Luau, ProfileService, Node.js, Postgres, Railway, Git.
