	-- [Progression part 11-plan: the plan: one entry per rod. The loader joins the parts in order into one scope.]
	local PLAN = {
		["Fortune Rod"] = {
			level = 0,
			done = function() return G.ownsRod("Fortune Rod") end,
			run = function()
				buyRod("Fortune Rod", 11000, "Fortune Rod shop")
				G.equipRod("Fortune Rod")
			end,
		},

		["Wisdom Rod"] = {
			level = 50,
			done = function() return G.ownsRod("Wisdom Rod") end,
			run = function()
				-- The thread (and any Ruby or Mythical Driftwood) usually turns up while grinding: keep them from the start.
				state.protected["Magic Thread"] = true
				state.protected["Ruby"] = true
				state.protected["Driftwood"] = { Mutation = "Mythical" }
				bestRod()
				fishUntil("level 50", function() return G.level() >= 50 end, { sell = true, zone = "XP spot" })
				gather("Magic Thread", 1, nil, function()
					fishUntil("a Magic Thread", have("Magic Thread", 1))
				end)
				gather("Ruby", 1, nil, getRuby)
				gather("Driftwood", 2, { Mutation = "Mythical" }, getMythicalDriftwood)
				goTo("Crafting station")
				G.craft("Wisdom Rod")
				if not waitFor(function() return G.ownsRod("Wisdom Rod") end, 10) then
					error("crafting the Wisdom Rod didn't work (see the log)", 0)
				end
			end,
		},

		["Heaven's Rod"] = {
			level = 220,
			done = function() return G.ownsRod("Heaven's Rod") and G.rodEnchant("Heaven's Rod", "enchant") == "Long" end,
			run = function()
				-- This stage fishes with the Wisdom Rod (more XP). Before levelling it gets Clever from Enchant Relics,
				-- and one roll for Wise with a Cosmic Relic: ours, else an alt's, else it goes on without (Cosmic
				-- Relics are rare, and the Tryhard Rod needs them later).
				if G.ownsRod("Wisdom Rod") then
					state.stageRod = "Wisdom Rod"
					if G.level() < 220 then
						if G.rodEnchant("Wisdom Rod", "enchant") ~= "Clever" then
							enchant("Wisdom Rod", { "Clever" }, "Enchant Relic", "enchant")
						end
						if G.rodEnchant("Wisdom Rod", "secondaryEnchant") ~= "Wise"
							and not enchant("Wisdom Rod", { "Wise" }, "Cosmic Relic", "secondaryEnchant", 1) then
							log("no Wise on the Wisdom Rod; levelling without it")
						end
					end
				end
				G.equipRod(state.stageRod or G.bestRod())
				fishUntil("level 220", function() return G.level() >= 220 end, { sell = true, zone = "XP spot" })
				if not G.ownsRod("Heaven's Rod") then
					for _, color in ipairs({ "Blue", "Green", "Yellow", "Red" }) do state.protected[color .. " Energy Crystal"] = true end

					if needCrystal("Blue") then
						local function hasPickaxe() return G.tool("Pickaxe") ~= nil or G.count("Pickaxe") > 0 end
						if not hasPickaxe() then
							earn(5000, "a Pickaxe")
							buyFromDisplay("Pickaxe", hasPickaxe, "Pickaxe shop")
							if not hasPickaxe() then error("couldn't buy a Pickaxe at the Pickaxe shop (see the log)", 0) end
						end
						if not mine("Blue crystal", "Blue Energy Crystal", "blue") then
							error("couldn't mine the Blue Energy Crystal (see the log)", 0)
						end
					end

					if needCrystal("Green") then
						talkTo("???", nil, { "crystal", "yes", "sure", "okay" }, "Shadowy figure")
					end

					-- The 5 puzzle buttons (Northern Summit.Puzzles.HardPuzzle.Buttons, one per island). Pressing one is
					-- handled on this side (PuzzleButton.lua: the prompt's Triggered tells the server), and a pressed
					-- button's prompt turns off. The server only takes one press about every 30 seconds: in every run,
					-- presses sooner than that after the last one that counted were ignored. So each button is pressed
					-- 32 seconds after the previous success, and any that didn't take get a second round.
					-- Only needed for the Red crystal: skipped once it's bought or placed.
					if needCrystal("Red") then
						state.watchNotices = true
						local BUTTON_GAP = 32
						local lastPressed = -math.huge
						local function pressButton(i)
							local spot = goTo(i == 1 and "Button 1 (Moosewood)" or ("Button " .. i))
							local prompt
							waitFor(function()
								prompt = G.promptsNear(spot, 60, "press")[1]
								return prompt ~= nil
							end, 6, 0.5)
							if not prompt then
								log("button " .. i .. ": no Press Button prompt here (already pressed)")
								return true
							end
							local waitLeft = BUTTON_GAP - (os.clock() - lastPressed)
							if waitLeft > 0 then
								setStatus("Buttons", ("button %d in %ds (the game takes one press about every 30s)"):format(i, math.ceil(waitLeft)))
								sleep(waitLeft)
							end
							for try, how in ipairs({ "hold", "key", "handler", "key" }) do
								G.pressPrompt(prompt, how, true)
								if waitFor(function() return not prompt.Enabled end, 3, 0.3) then
									lastPressed = os.clock()
									log(("button %d: pressed (%s)"):format(i, how))
									return true
								end
							end
							log("button " .. i .. ": didn't take after 4 tries")
							return false
						end
						local missed = {}
						for i = 1, 5 do
							if not pressButton(i) then missed[#missed + 1] = i end
						end
						for _, i in ipairs(missed) do
							log("button " .. i .. ": second round")
							pressButton(i)
						end
					end

					-- After the buttons, Hiker #12 sells the Red Energy Crystal.
					if needCrystal("Red") then
						earn(250000, "the Red Energy Crystal")
						-- Talk to him first (after the buttons), then buy it from the display next to him
						-- (world.interactables["Red Energy Crystal"], "View [250,000 C$]"). He offers "Pay C$250,000.",
						-- "Take the crystal and run." (that one gets you knocked out and robbed) and "Yeah, no shot.
						-- Goodbye.": only paying is ever picked.
						talkTo("Hiker #12", nil, { "pay" }, "Hiker #12", true)
						buyFromDisplay("Red Energy Crystal", function() return G.count("Red Energy Crystal") > 0 end, "Hiker #12")
						if G.count("Red Energy Crystal") < 1 then
							state.watchNotices = false
							error("couldn't buy the Red Energy Crystal (are all 5 buttons pressed? see the log)", 0)
						end
					end
					state.watchNotices = false

					-- Order (user): Blue, Green, the buttons, Red (Hiker #12), then Yellow: an Avalanche Totem at the yellow
					-- spot, clear out, collect it 5 seconds later.
					if needCrystal("Yellow") and not getYellowCrystal() then
						error("couldn't get the Yellow Energy Crystal (see the log)", 0)
					end

					-- Each crystal goes in its own pedestal (user's order: orange/Yellow, Red, Blue, Green), then the rod is
					-- bought; short on C$, it's fished for at the C$ farm spot first (earn).
					for _, color in ipairs({ "Yellow", "Red", "Blue", "Green" }) do
						if not placeCrystal(color) then
							error(("couldn't put the %s Energy Crystal in its pedestal (see the log)"):format(color), 0)
						end
					end

					buyRod("Heaven's Rod", 800000, "Heaven's Rod shop")
				end
				enchant("Heaven's Rod", { "Long" }, "Enchant Relic", "enchant")
			end,
		},

		["Pinion's Aria"] = {
			level = 424,
			done = function()
				return G.ownsRod("Pinion's Aria") and ariaStep("finale") and not G.questActive("Aria_FinalChallenge")
					and G.rodEnchant("Pinion's Aria", "enchant") == "Clever" and G.rodEnchant("Pinion's Aria", "secondaryEnchant") == "Wise"
			end,
			run = function()
				fishUntil("level 424", function() return G.level() >= 424 end, { sell = true, zone = "XP spot", rod = "Wisdom Rod" })
				if not G.ownsRod("Pinion's Aria") then
					-- 1. An Enchant Relic with the Chaotic mutation, put in at its spot next to the DJ Spinopus spot.
					if not ariaStep("relic") then
						getChaoticRelic()
						if not (chaoticRelic() and placeItem("Chaotic relic spot", "Enchant Relic", CHAOTIC, nil, true)) then
							error("couldn't put the Chaotic relic in (see the log)", 0)
						end
						ariaDone("relic")
					end
					-- 2. The Songstress in the music venue.
					if not ariaStep("met") then
						if not songstressAt("Mysterious Songstress") then error("couldn't find the Songstress (see the log)", 0) end
						ariaDone("met")
					end
					-- 3. A DJ Spinopus (the "musical fish", in the cave outside the venue). She asks you to play it: it's
					-- held and clicked a few times. Then she tells you about the Harmonic Dove and hands over a Hang Glider.
					if not ariaStep("spinopus") then
						state.protected["DJ Spinopus"] = true
						fishUntil("a DJ Spinopus", have("DJ Spinopus", 1), { zone = "DJ Spinopus spot" })
						songstressAt("Mysterious Songstress")
						if G.hold("DJ Spinopus") then
							for _ = 1, 10 do
								G.tapScreen()
								sleep(0.6)
							end
							log("played the DJ Spinopus (10 clicks)")
						else
							log("couldn't hold the DJ Spinopus to play it")
						end
						G.unhold()
						sleep(1)
						songstressAt("Mysterious Songstress")
						ariaDone("spinopus")
					end
					-- 4. The glider ring course from Castaways peak (Castaway Cliffs) up to the island above the clouds.
					if not ariaStep("cloud") then
						local flown = false
						for attempt = 1, 3 do
							flown = flyRingCourse()
							if flown then break end
							log(("ring course: attempt %d didn't finish"):format(attempt))
						end
						if not flown then
							error("couldn't finish the glider ring course (see the log): fly it yourself, then click \"Mark the ring course done\" in the Rods section", 0)
						end
						ariaDone("cloud")
					end
					-- 5. Long on the Heaven's Rod, then a Harmonic Dove with the Heavenly mutation at the Cloud (legit casts there), handed in
					-- for Pinion's Aria (to the venue Songstress).
					if G.rodEnchant("Heaven's Rod", "enchant") ~= "Long" then enchant("Heaven's Rod", { "Long" }, "Enchant Relic", "enchant") end
					state.protected["Harmonic Dove"] = { Mutation = "Heavenly" }
					state.protected["Heavenly Harmonic Dove"] = true
					fishUntil("a Heavenly Harmonic Dove", heavenlyDove, { rod = "Heaven's Rod", zone = "Cloud", bait = "Worm" })
					for _, where in ipairs({ "Mysterious Songstress" }) do
						songstressAt(where)
						if waitFor(function() return G.ownsRod("Pinion's Aria") end, 10) then break end
					end
					if not G.ownsRod("Pinion's Aria") then error("the Songstress didn't hand over Pinion's Aria (see the log)", 0) end
				end
				-- 6. 42 catches with Pinion's Aria at the DJ Spinopus spot (Crystal Cove); she gives Megalodon Hunt Totems
				-- for it. The game's quest (Aria_Tutorial) says whether it's still to do, not the totems: an account can
				-- have one from before (user: the catches were skipped and the totem used straight away).
				local quests = G.activeQuests()
				if not ariaStep("tutorial") or G.questActive("Aria_Tutorial") then
					if quests and not G.questActive("Aria_Tutorial") and not G.questActive("Aria_FinalChallenge") then
						songstressAt("Mysterious Songstress") -- she gives the quest
					end
					if not quests or G.questActive("Aria_Tutorial") then
						-- The reel played out (bar 100%, progress speed 100%, no Super Instant): Super Instant catches
						-- didn't count (user). If she still doesn't take them, 10 more and back to her, a few times.
						local function handedIn() return quests ~= nil and not G.questActive("Aria_Tutorial") end
						local fishOpts = { rod = "Pinion's Aria", zone = "DJ Spinopus spot", minigame = true }
						for round = 1, 4 do
							local count = round == 1 and 42 or 10
							fishCatches(("%d fish at the DJ Spinopus spot"):format(count), count, fishOpts)
							log("Pinion's Aria 42 fish quest: " .. G.questInfo("Aria_Tutorial"))
							songstressAt("Mysterious Songstress")
							if waitFor(handedIn, 10) or not quests then break end
							log("the Songstress didn't take them yet; 10 more")
						end
						if quests and G.questActive("Aria_Tutorial") then error("the Songstress didn't take the 42 fish (see the log)", 0) end
					end
					ariaDone("tutorial")
				end
				-- 7. A Megalodon: the hunt totem, Pinion's Aria and Shark Head bait (or Tryhard Worm), fished from a raft
				-- on the hunt's zone; then back to her. Only once she's given the challenge (Aria_FinalChallenge), so no
				-- totem is spent before it counts.
				-- The game's quest says whether it's still on (user: a hand-in that never happened was taken as done).
				-- The Megalodon caught is saved as its own step, so a failed hand-in doesn't mean hunting another.
				if not ariaStep("finale") or G.questActive("Aria_FinalChallenge") then
					if not ariaStep("megalodon") then
						if quests and not G.questActive("Aria_FinalChallenge") then songstressAt("Mysterious Songstress") end
						if quests and not G.questActive("Aria_FinalChallenge") then
							error("the Songstress hasn't given the Megalodon challenge (see the log)", 0)
						end
						local bait = (G.baitCount("Shark Head") > 0 and "Shark Head") or (G.baitCount("Tryhard Worm") > 0 and "Tryhard Worm") or nil
						if not bait then log("no Shark Head or Tryhard Worm bait; fishing for the Megalodon without") end
						if not huntMegalodon(bait) then error("no Megalodon from the hunt totems (see the log)", 0) end
						ariaDone("megalodon")
					end
					-- Handed in once the quest is gone from the game's list (a few tries).
					local function handedIn() return quests ~= nil and not G.questActive("Aria_FinalChallenge") end
					for _ = 1, 3 do
						songstressAt("Mysterious Songstress")
						if not quests or waitFor(handedIn, 8) then break end
						log("the Songstress hasn't taken the Megalodon yet; talking to her again")
					end
					-- Still on: she says "Good luck!" when the Megalodon didn't count (user: an instant-reeled one), so the next run
					-- hunts another.
					if quests and G.questActive("Aria_FinalChallenge") then
						state.settings.aria.megalodon = nil
						saveSettings()
						error("the Songstress hasn't counted the Megalodon (\"Good luck!\"); it'll hunt another, reel played out", 0)
					end
					ariaDone("finale")
				end
				-- Clever and Wise (user): Clever with Enchant Relics, then Wise (a secondary) with Cosmic Relics.
				enchant("Pinion's Aria", { "Clever" }, "Enchant Relic", "enchant")
				if G.rodEnchant("Pinion's Aria", "secondaryEnchant") ~= "Wise"
					and not enchant("Pinion's Aria", { "Wise" }, "Cosmic Relic", "secondaryEnchant") then
					error("Wise on Pinion's Aria needs a Cosmic Relic (an alt with one, or a Starfall Totem)", 0)
				end
			end,
		},

		["Tryhard Rod"] = {
			level = 999,
			done = function()
				local secondary = G.rodEnchant("Tryhard Rod", "secondaryEnchant")
				return G.ownsRod("Tryhard Rod") and G.rodEnchant("Tryhard Rod", "enchant") == "Herculean"
					and (secondary == "Sea Prince" or secondary == "Glittered" or secondary == "Wise" or G.count("Cosmic Relic", nil, true) == 0)
			end,
			run = function()
				bestRod()
				fishUntil("level 999", function() return G.level() >= 999 end, { sell = true, zone = "XP spot" })
				local roRed = function() talkTo("RoRed", "RoRed", { "yes", "sure", "okay", "ready" }, "RoRed") end
				if not G.ownsRod("Tryhard Rod") then
					-- Parts 1 and 2 (TryhardRodQuest): perfect catches in a row with the Flimsy Rod.
					roRed()
					fishCatches("10 perfect catches with the Flimsy Rod", 10, { rod = "Flimsy Rod", perfect = true })
					roRed()
					fishCatches("25 perfect casts and catches with the Flimsy Rod", 25, { rod = "Flimsy Rod", perfect = true })
					roRed()
					-- Part 3: a Megalodon on a Hasty + Tryhard Flimsy Rod.
					enchant("Flimsy Rod", { "Hasty" }, "Enchant Relic", "enchant")
					enchant("Flimsy Rod", { "Tryhard" }, "Cosmic Relic", "secondaryEnchant")
					if G.count("Megalodon Hunt Totem", nil, true) > 0 then G.useItem("Megalodon Hunt Totem") end
					local bait = G.baitCount("Tryhard Worm") > 0 and "Tryhard Worm" or nil
					fishUntil("a Megalodon", function() return (state.caught["Megalodon"] or 0) > 0 end, { rod = "Flimsy Rod", bait = bait, zone = "None" })
					roRed()
					if not waitFor(function() return G.ownsRod("Tryhard Rod") end, 20) then
						error("RoRed didn't hand over the Tryhard Rod (see the log)", 0)
					end
				end
				enchant("Tryhard Rod", { "Herculean" }, "Exalted Relic", "enchant")
				-- Second slot only if a Cosmic Relic is on hand; no asking alts for this one.
				if G.count("Cosmic Relic", nil, true) > 0 then
					state.settings.shareWithAlts, state.sharePaused = false, state.settings.shareWithAlts
					enchant("Tryhard Rod", { "Sea Prince", "Glittered", "Wise" }, "Cosmic Relic", "secondaryEnchant")
					state.settings.shareWithAlts = state.sharePaused
				end
			end,
		},
	}

