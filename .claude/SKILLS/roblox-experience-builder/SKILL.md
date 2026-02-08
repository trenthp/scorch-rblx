---
name: roblox-experience-builder
description: Comprehensive Roblox experience development agent. Use when planning a new Roblox game, setting up monetization, optimizing for discovery, improving retention, or preparing for launch. Guides through the full lifecycle from concept to monetization. Triggers on phrases like "build a Roblox game", "monetize my experience", "improve retention", "prepare for launch", "set up GamePasses", or any holistic game development planning.
---

# Roblox Experience Builder

Interactive workflow for building successful Roblox experiences. Work through each phase or jump to specific sections as needed.

## Workflow Phases

1. **Concept & Planning** - Define your experience
2. **Project Setup** - Structure and tooling
3. **Core Systems** - Essential game systems
4. **Monetization** - Revenue strategy
5. **Discovery** - Visibility optimization
6. **Launch Checklist** - Pre-release validation
7. **Post-Launch** - Analytics and iteration

---

## Phase 1: Concept & Planning

### Discovery Questions
Ask these to understand the experience:

1. **Genre**: What type of game? (Simulator, Obby, Tycoon, RPG, Horror, Social, Fighting, etc.)
2. **Core Loop**: What does the player do repeatedly? (Click→Earn→Upgrade? Complete levels? Battle?)
3. **Target Audience**: Age range? Casual or hardcore? Session length target?
4. **Unique Hook**: What makes this different from competitors?
5. **Scope**: Solo dev or team? Timeline? MVP features vs full vision?

### Genre Templates

| Genre | Core Loop | Session Target | Key Systems |
|-------|-----------|----------------|-------------|
| Simulator | Gather→Sell→Upgrade→Rebirth | 15-30 min | Currency, Pets, Rebirth, Leaderboards |
| Obby | Attempt→Fail→Improve→Complete | 10-20 min | Checkpoints, Difficulty progression |
| Tycoon | Build→Earn→Expand | 20-40 min | Droppers, Conveyors, Upgrades |
| RPG | Quest→Fight→Loot→Level | 30-60 min | Combat, Inventory, Quests, Stats |
| Horror | Explore→Survive→Escape | 15-25 min | AI, Atmosphere, Events |
| Social/Roleplay | Interact→Customize→Express | Open-ended | Emotes, Housing, Customization |

### Core Loop Design
A good core loop has:
- **Action** - What player does (click, build, fight)
- **Reward** - Immediate feedback (currency, XP, items)
- **Progression** - Long-term growth (unlocks, power, cosmetics)
- **Aspiration** - Goals to chase (leaderboards, rare items, completion)

---

## Phase 2: Project Setup

### Recommended Structure
```
game
├── ReplicatedStorage/
│   ├── Modules/           -- Shared code
│   │   ├── Data/          -- Data definitions, configs
│   │   └── Util/          -- Helper functions
│   ├── Remotes/           -- RemoteEvents & RemoteFunctions
│   │   ├── Events/
│   │   └── Functions/
│   └── Assets/            -- Shared models, UI templates
├── ServerStorage/
│   ├── Modules/           -- Server-only modules
│   └── Assets/            -- Server-only assets
├── ServerScriptService/
│   ├── Services/          -- Game systems (DataService, CombatService, etc.)
│   └── Init.server.lua    -- Bootstrap script
├── StarterPlayer/
│   ├── StarterPlayerScripts/
│   │   ├── Controllers/   -- Client systems
│   │   └── Init.client.lua
│   └── StarterCharacterScripts/
├── StarterGui/
│   └── [UI ScreenGuis]
└── Workspace/
    ├── Map/
    └── SpawnLocation
```

### External Development (Recommended for teams)
Use Rojo + VS Code + Git:

**default.project.json**
```json
{
  "name": "MyExperience",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Modules": { "$path": "src/shared" },
      "Remotes": { "$className": "Folder" }
    },
    "ServerScriptService": {
      "Services": { "$path": "src/server" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Controllers": { "$path": "src/client" }
      }
    }
  }
}
```

### Essential Services Checklist
- [ ] Data persistence (DataStoreService or ProfileService)
- [ ] Client-server communication (Remotes)
- [ ] Player management (join/leave handling)
- [ ] UI system
- [ ] Audio manager
- [ ] Settings/preferences

---

## Phase 3: Core Systems

### Data Service (Use ProfileService for production)
See `references/core-systems.md` for full implementation.

Key requirements:
- Session locking (prevent duplication)
- Auto-save (every 30-60 seconds)
- BindToClose handling
- Data versioning/migration

### Required Patterns by Genre

**All Games:**
- Player data persistence
- Settings (audio, graphics, controls)
- Notification/feedback system

**Simulators:**
- Currency system (multiple currencies)
- Pet/companion system
- Rebirth mechanics
- Collection tracking

**Combat Games:**
- Damage calculation (server-authoritative)
- Hitbox/raycast detection
- Cooldown management
- Status effects

**Social/Roleplay:**
- Emote system
- Housing/plots
- Trading
- Customization saving

---

## Phase 4: Monetization

### Revenue Streams

| Type | Use Case | Purchase Limit |
|------|----------|----------------|
| **GamePass** | Permanent perks (2x coins, VIP) | One-time |
| **DevProduct** | Consumables (currency, crates) | Unlimited |
| **Premium Payouts** | Engagement time from Premium users | Automatic |

### GamePass Strategy

**Tier Pricing (adjust for your audience):**
- **Starter** (25-75 R$): Minor conveniences, cosmetics
- **Mid** (100-250 R$): Significant perks, 2x multipliers
- **Premium** (400-1000 R$): Major advantages, VIP status
- **Whale** (1500+ R$): Exclusive items, ultimate bundles

**High-Converting GamePasses:**
1. **2x/3x Multipliers** - Coins, XP, damage (best seller)
2. **VIP Access** - Exclusive areas, perks, badge
3. **Auto-Collect/AFK** - Passive progression
4. **Extra Storage** - Inventory slots, pet capacity
5. **Cosmetics Bundle** - Exclusive skins, effects

### DevProduct Strategy

**Consumables that work:**
- In-game currency (tiered: 100, 500, 1000, 5000)
- Crates/mystery boxes
- Temporary boosts (30min 2x)
- Revives/extra lives
- Skip timers

**Pricing Psychology:**
- Offer 3+ tiers (anchor effect)
- Best value on middle tier
- Include "bonus" amounts (500 + 50 FREE!)

### Premium Payouts Optimization
You earn from Premium subscribers' time in your game:
- Design for longer sessions (quests, goals)
- Add AFK-friendly features (auto-farming with GamePass)
- Create reasons to return daily

### Monetization Implementation
```lua
-- GamePass check
local MarketplaceService = game:GetService("MarketplaceService")
local VIP_PASS_ID = 123456789

local function hasVIP(player: Player): boolean
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS_ID)
    end)
    return success and owns
end

-- DevProduct handling
local COIN_PRODUCTS = {
    [111111] = 100,   -- 100 coins
    [222222] = 500,   -- 500 coins
    [333333] = 1000,  -- 1000 coins
}

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
    
    local coins = COIN_PRODUCTS[receiptInfo.ProductId]
    if coins then
        -- Add coins to player (your data system)
        PlayerData.AddCoins(player, coins)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    return Enum.ProductPurchaseDecision.NotProcessedYet
end
```

### Monetization Ethics
**DO:**
- Make free experience complete and fun
- Offer cosmetics and conveniences
- Provide good value
- Be transparent about what purchases give

**DON'T:**
- Lock core content behind paywalls
- Create pay-to-win advantages in PvP
- Use manipulative dark patterns
- Make game unplayable without purchases

---

## Phase 5: Discovery

### Algorithm Factors (Ranked by Impact)

1. **Qualified Play-Through Rate (QPTR)** - % who click AND play 3+ minutes
2. **Session Duration** - Average time per visit
3. **Day 1/7/30 Retention** - Return visit rates
4. **Like Ratio** - Positive vs negative votes
5. **Growth Velocity** - Rate of player increase

### Thumbnail Optimization

**Best Practices:**
- 1920x1080 resolution
- Clear, readable at small sizes
- Show gameplay, not just logo
- Use bright, contrasting colors
- Test multiple thumbnails (Roblox A/B tests automatically)
- Avoid excessive text (gets translated/distorted)

**Upload 5-10 thumbnails** - Roblox will show different ones to different users and optimize automatically.

### Icon Guidelines
- 512x512 square
- Recognizable at small sizes
- Consistent brand with thumbnails
- Avoid tiny details that disappear

### Title & Description SEO

**Title:**
- Include main keyword (e.g., "Simulator", "Tycoon", "Obby")
- Keep under 50 characters
- Make it memorable and searchable

**Description:**
- First 2 lines most important (shown in preview)
- Include relevant keywords naturally
- List key features
- Update codes/changelogs
- Add social links

### First-Time User Experience (FTUE)
Critical for QPTR - player must understand your game in <60 seconds:

1. **Immediate action** - Player does something within 5 seconds
2. **Clear objective** - What am I trying to do?
3. **Quick reward** - Dopamine hit in first minute
4. **Progress preview** - Show what they can achieve

---

## Phase 6: Launch Checklist

### Pre-Launch Validation

**Core Functionality:**
- [ ] Data saves and loads correctly
- [ ] No critical errors in console
- [ ] All purchases work and grant rewards
- [ ] Tested on mobile, PC, console
- [ ] Performance acceptable (60fps target, 30fps minimum)

**Content:**
- [ ] At least 30 minutes of content for first session
- [ ] Clear progression path visible
- [ ] Tutorial/onboarding complete
- [ ] All UI elements functional

**Monetization:**
- [ ] GamePasses created and tested
- [ ] DevProducts created and tested
- [ ] Purchase prompts appear correctly
- [ ] Purchases persist across sessions

**Discovery:**
- [ ] 5+ thumbnails uploaded
- [ ] Icon uploaded
- [ ] Description written with keywords
- [ ] Game properly categorized

**Settings:**
- [ ] Enable Premium Payouts
- [ ] Set appropriate age rating
- [ ] Configure server size (start small: 10-20)
- [ ] Enable private servers if appropriate

### Soft Launch Strategy
1. **Friends & Family** - 10-20 testers, gather feedback
2. **Small Community** - Discord, DevForum, 50-100 players
3. **Monitor Analytics** - Watch for crashes, low retention
4. **Iterate** - Fix critical issues before wide release
5. **Full Launch** - Marketing push, sponsor if budget allows

---

## Phase 7: Post-Launch

### Key Metrics to Track

| Metric | Good | Great | Action if Low |
|--------|------|-------|---------------|
| D1 Retention | 15% | 25%+ | Improve FTUE, core loop |
| D7 Retention | 5% | 10%+ | Add progression depth |
| D30 Retention | 2% | 5%+ | Add endgame, social features |
| Avg Session | 10min | 20min+ | More content, goals |
| QPTR | 2% | 4%+ | Better thumbnails, faster FTUE |
| Like Ratio | 70% | 85%+ | Fix bugs, balance issues |

### Update Cadence
- **Weekly**: Bug fixes, small balance tweaks
- **Bi-weekly**: QoL improvements, minor content
- **Monthly**: New features, events
- **Quarterly**: Major updates, new systems

### Community Building
- Create Discord server
- Respond to feedback
- Run events and giveaways
- Feature community content
- Announce updates in-game and social

### Revenue Analysis
Track revenue per visit (RPV):
- **Low** (<0.5 R$/visit): Add more purchase options, improve prompts
- **Average** (0.5-1.5 R$/visit): Optimize pricing, add bundles
- **Good** (1.5-3+ R$/visit): Focus on retention and traffic

---

## Quick Reference: Genre-Specific Checklists

### Simulator Checklist
- [ ] Multiple currencies (soft + premium)
- [ ] Pet/companion system
- [ ] Rebirth system with multipliers
- [ ] Collection/achievement tracking
- [ ] Leaderboards
- [ ] Daily rewards
- [ ] Trading system
- [ ] 2x GamePass, Auto-collect GamePass

### Obby Checklist
- [ ] Checkpoint system
- [ ] Stage progression tracking
- [ ] Skip stage DevProduct
- [ ] Speed/gravity coils GamePass
- [ ] Difficulty indicators
- [ ] Timer/speedrun mode
- [ ] Rage quit prevention (not too hard early)

### Tycoon Checklist
- [ ] Dropper/conveyor systems
- [ ] Upgrade tiers
- [ ] Multiple plots (for friends)
- [ ] Save/load tycoon state
- [ ] 2x income GamePass
- [ ] Auto-collect GamePass
- [ ] Premium plot/items

### RPG Checklist
- [ ] Combat system (balanced)
- [ ] Quest system
- [ ] Inventory management
- [ ] Equipment/stats
- [ ] Leveling system
- [ ] Boss encounters
- [ ] Party/group play
- [ ] Loot tables

---

## Support Files

- `references/core-systems.md` - Full implementations of data, currency, inventory systems
- `references/monetization-scripts.md` - GamePass and DevProduct code templates
- `references/ui-patterns.md` - Common UI layouts and scripts
