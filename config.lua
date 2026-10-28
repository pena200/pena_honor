Config = {}

-- 'auto' detects qbx_core / qb-core / es_extended, otherwise falls back to standalone (license identifier).
-- Force one with: 'esx' | 'qb' | 'qbox' | 'standalone'
Config.Framework = 'auto'

-- Prints what the kill/assault detection sees to the F8 console and the server console. Turn on to debug.
Config.Debug = false

-- Show "<name> now has <n> honor." in chat after /addhonor and /sethonor
Config.AdminChatFeedback = false

-- Configuration of minimum and maximum and default
Config.MinHonor   = -1000
Config.MaxHonor   = 1000
Config.StartHonor = 0

-- Default key for the on-demand honor display (players can rebind it in Settings > Key Bindings > FiveM).
-- Set to false to have no key at all and use /honor or the radial menu only.
-- Note: players who already used the old default keep their saved binding until they rebind it.
Config.Keybind = 'LMENU'

-- Adds an "Honor" section to the ox_lib radial menu (only if ox_lib is running).
-- Using a custom radial menu? Make its item run  ExecuteCommand('honor')  or  exports.pena_honor:ShowHonor()
Config.Radial = {
    enabled = true,
    label   = 'Honor',
    icon    = 'bolt', -- Font Awesome icon name
}

-- Native GTA sounds: { sound name, sound set }. Set an entry to false to mute just that one.
-- Find more with a sound browser, for example the NativeDB sound lists.
Config.Sounds = {
    enabled   = true,
    gain      = { 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET' },    -- honor went up
    loss      = { 'CHECKPOINT_MISSED',  'HUD_MINI_GAME_SOUNDSET' },    -- honor went down
    tierUp    = { 'RANK_UP',            'HUD_AWARDS' },                -- reached a better tier
    tierDown  = { 'LOSER',              'HUD_AWARDS' },                -- dropped to a worse tier
    open      = { 'SELECT',             'HUD_FRONTEND_DEFAULT_SOUNDSET' }, -- /honor, key or radial opens the bar
    close     = { 'BACK',               'HUD_FRONTEND_DEFAULT_SOUNDSET' }, -- the bar fades away after /honor
    refused   = { 'ERROR',              'HUD_FRONTEND_DEFAULT_SOUNDSET' }, -- a shop refused to serve you (bad honor)
    tierDelay = 700, -- ms before the tier sound, so it doesn't overlap the +/- sound
}

Config.HUD = {
    -- top-left | top-center | top-right | middle-left | middle-right | bottom-left | bottom-center | bottom-right
    position  = 'bottom-center', -- the honor bar with the badge and title cluster on top
    duration  = 5000,            -- ms the bar stays on screen
    showValue = false,           -- show the raw number next to the title
}

-- neon for bad honor, baby blue for good honor
Config.Colors = {
    good    = '#89CFF0',
    goodAlt = '#c9ecff',
    bad     = '#ff2e97',
    badAlt  = '#9b3dff',
    neutral = '#d9d4ff',
}

-- Honor pool: batches rapid changes into one smooth update instead of spamming notifications
Config.Pool = {
    enabled  = true,
    interval = 2500, -- ms
}

-- Detects kills and assaults made by the player on the client and reports them to the server.
-- Only actions with auto = true below are ever accepted from clients.
Config.AutoDetect = {
    enabled = true,
    assault = true,           -- hurting (not killing) a peaceful ped counts as hit_civilian
    gangsAreHostile = true,   -- gang member peds count as hostile (killing them is not a crime)
    threaten = true,          -- aiming a weapon at a peaceful ped for 3 seconds (threaten_civilian)
    carjack  = true,          -- pulling a ped out of their vehicle (carjack)
    -- Killing these animals counts as kill_animal (pets and livestock)
    protectedAnimals = {
        'a_c_cat_01', 'a_c_chop', 'a_c_husky', 'a_c_poodle', 'a_c_pug', 'a_c_retriever',
        'a_c_rottweiler', 'a_c_shepherd', 'a_c_westy', 'a_c_cow', 'a_c_pig', 'a_c_hen',
    },
    ignoredPedModels = {
        -- 's_m_y_cop_01', 's_m_y_sheriff_01',
    },
}
Config.AutoCooldown = 1500 -- ms between the same auto action per player

-- Killing a player whose honor is at or below this counts as taking down an outlaw (kill_outlaw, honor gain)
-- instead of murder. The server decides this from the victim's real honor.
Config.OutlawHonor = -350

-- Named actions. Other resources can trigger them with exports.pena_honor:ApplyAction(src, 'help_citizen')
-- auto       = detected by this resource on the client and checked by the server
-- maxPerHour = cap on how much honor one player can get from that action per hour (abuse guard)
-- cooldown   = seconds a player must wait before the same action counts again
-- enabled    = set to false to switch an action off (for example a detected one you don't want)
-- Your own activities: add them here, or register them from another resource with
--   exports.pena_honor:RegisterAction('my_activity', { label = 'Did something', amount = 10, cooldown = 60 })
Config.Actions = {
    -- Detected automatically ------------------------------------------------------------
    kill_civilian = { label = 'Killed a civilian',        amount = -40, auto = true },
    kill_player   = { label = 'Killed a player',          amount = -75, auto = true },
    kill_cop      = { label = 'Killed a police officer',  amount = -60, auto = true },
    hit_civilian  = { label = 'Assaulted a civilian',     amount = -8,  auto = true },
    kill_animal   = { label = 'Killed a pet or livestock', amount = -15, auto = true },
    threaten_civilian = { label = 'Threatened a civilian', amount = -3, auto = true },
    carjack       = { label = 'Carjacked a vehicle',       amount = -25, auto = true },
    kill_hostile  = { label = 'Defended yourself',        amount = 5,   auto = true, maxPerHour = 30 },
    kill_outlaw   = { label = 'Took down an outlaw',      amount = 30,  maxPerHour = 90 }, -- chosen by the server, never sent by clients

    -- Triggered by other resources (exports.pena_honor:ApplyAction(src, 'key')) ---------
    help_citizen  = { label = 'Helped a citizen',         amount = 25 },
    revive_player = { label = 'Saved a life',             amount = 20, maxPerHour = 80 },
    arrest        = { label = 'Arrested a criminal',      amount = 15, maxPerHour = 60 },
    donation      = { label = 'Made a donation',          amount = 10, maxPerHour = 50 },
    job_done      = { label = 'Honest day of work',       amount = 3,  maxPerHour = 30 },
    robbery       = { label = 'Committed a robbery',      amount = -50 },
    heist         = { label = 'Pulled off a heist',       amount = -100 },
    steal_vehicle = { label = 'Stole a vehicle',          amount = -15 },
    mugging       = { label = 'Mugged someone',           amount = -30 },
    jailed        = { label = 'Sent to prison',           amount = -20 },
}

-- Hook other resources without editing them: when one of these SERVER events fires,
-- the action is applied. 'arg' is which event argument holds the player's server id,
-- or use useSource = true when the event is triggered from the client (source is the player).
-- Check the real event names in your own resources before enabling any of these.
Config.Listeners = {
    -- { event = 'your_robbery_script:server:finished', action = 'robbery', arg = 1 },
    -- { event = 'your_ambulance:server:revived',       action = 'revive_player', useSource = true },
    -- { event = 'your_police:server:arrested',         action = 'arrest', arg = 1 },
}

-- Benefits and penalties
-- ----------------------
-- Honor gives three kinds of standing, decided by the mood of the player's tier (see Config.Tiers):
--   good tiers    -> can get benefits   (Config.Benefits)
--   neutral tiers -> nothing, ever
--   bad tiers     -> get penalties      (Config.Penalties)
-- This is enforced in code, so listing the wrong tier below has no effect.
-- Each entry is a name with a value per tier id. Read them from any script with
--   exports.pena_honor:GetBenefit(src, 'name') / GetPenalty(src, 'name')   (server)
--   exports.pena_honor:GetBenefit('name') / GetPenalty('name')             (client)

-- Nothing is built in for good honor: add your own and read them from your scripts.
Config.Benefits = {
    -- shop_discount       = { decent = 5, honorable = 10, noble = 15, paragon = 20 },
    -- bounty_reward_bonus = { noble = 10, paragon = 25 },
    -- my_perk             = { honorable = true, paragon = true },
}

Config.Penalties = {
    -- Built in: shops refuse to serve you. Value = percent chance a shop refuses each time you try to open it.
    refuse_service = { rogue = 25, scoundrel = 60, public_enemy = 100 },
    -- Built in: peds near you get scared and run away. Value = radius in meters.
    npc_fear       = { rogue = 5, scoundrel = 8, public_enemy = 12 },
    -- Your own, for example:
    -- extra_prices = { scoundrel = 25, public_enemy = 50 },   -- percent you could add to prices in your store script
}

-- Built-in penalty: ox_inventory shops refuse to open (other store scripts can use exports.pena_honor:ShouldRefuseService)
Config.ShopRefusal = {
    enabled      = true,
    memory       = 60,   -- seconds a refused shop keeps refusing you, so you can't just spam it until it opens
    notify       = true, -- ox_lib notification
    message      = 'They refuse to serve you.',
    excludeShops = {     -- shop types that always serve everyone, keyed by shop type name
        -- Police = true,
    },
}

-- Built-in penalty: peds within the radius react and flee from you
Config.NpcFear = {
    enabled    = true,
    interval   = 2000, -- ms between checks
    maxPerTick = 5,    -- peds scared per check
}

-- Optional Discord logging
Config.Webhook = {
    enabled = false,
    url     = '',
}

-- Keep sorted by min, lowest first. A player gets the last tier whose min is <= their honor.
-- mood decides the HUD color: 'good' | 'neutral' | 'bad'
Config.Tiers = {
    { id = 'public_enemy', min = -1000, mood = 'bad',     male = 'Public Enemy', female = 'Public Enemy' },
    { id = 'scoundrel',    min = -700,  mood = 'bad',     male = 'Scoundrel',    female = 'Scoundrel' },
    { id = 'rogue',        min = -350,  mood = 'bad',     male = 'Rogue',        female = 'Rogue' },
    { id = 'shady',        min = -100,  mood = 'neutral', male = 'Shady',        female = 'Shady' },
    { id = 'plain',        min = -20,   mood = 'neutral', male = 'Plain',        female = 'Plain' },
    { id = 'decent',       min = 100,   mood = 'good',    male = 'Decent',       female = 'Decent' },
    { id = 'honorable',    min = 350,   mood = 'good',    male = 'Honorable',    female = 'Honorable' },
    { id = 'noble',        min = 700,   mood = 'good',    male = 'Gentleman',    female = 'Lady' },
    { id = 'paragon',      min = 950,   mood = 'good',    male = 'Paragon',      female = 'Paragon' },
}

-- Honor change icon (+ or - with a round badge) that slides in from the side of the screen
-- good = baby blue, bad = pink/purple
Config.Notify = {
    enabled    = true,
    position   = 'middle-right', -- top-right | middle-right | bottom-right | top-left | middle-left | bottom-left
    duration   = 4000,        -- ms
    max        = 3,           -- icons stacked at once
    showReason = false,       -- also show the reason text next to the icon
}