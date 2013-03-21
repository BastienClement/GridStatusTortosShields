--[[
	Copyright (c) 2013 Bastien Clément

	Permission is hereby granted, free of charge, to any person obtaining a
	copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be included
	in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local GridRoster = Grid:GetModule("GridRoster")
local GridStatus = Grid:GetModule("GridStatus")

local GridStatusTortosShields = GridStatus:NewModule("GridStatusTortosShields")

local SPELL_SHIELD, SPELL_SHIELD_FULL = GetSpellInfo(137633), GetSpellInfo(140701)

GridStatusTortosShields.defaultDB = {
	unit_crystal_shell = {
		color = { r = 0.84, g = 0.32, b = 0, a = 1.0 },
		colorFull = { r = 0.42, g = 0.76, b = 0.11, a = 1.0 },
		text = "Crystal Shell",
		enable = true,
		priority = 30,
		range = false
	}
}

GridStatusTortosShields.menuName = "Tortos: "..SPELL_SHIELD
GridStatusTortosShields.options = false

local settings
local tracking = false
local unitHasShield = {}

local TortosShields_options = {
	["break1"] = {
		type = "description",
		order = 80,
		name = "",
	},
	["color"] = {
		type = "color",
		name = "Color 1",
		desc = "Color when the shield is not fully stacked",
		hasAlpha = true,
		order = 81,
		get = function ()
			local color = settings.color
			return color.r, color.g, color.b, color.a
		end,
		set = function (_, r, g, b, a)
			local color = settings.color
			color.r = r
			color.g = g
			color.b = b
			color.a = a or 1
		end,
	},
	["colorFull"] = {
		type = "color",
		name = "Color 2",
		desc = "Color once the shield is fully stacked.",
		hasAlpha = true,
		order = 82,
		get = function ()
			local color = settings.colorFull
			return color.r, color.g, color.b, color.a
		end,
		set = function (_, r, g, b, a)
			local color = settings.colorFull
			color.r = r
			color.g = g
			color.b = b
			color.a = a or 1
		end,
	},
	["opacity"] = false
}

function GridStatusTortosShields:OnInitialize()
	self.super.OnInitialize(self)
	self:RegisterStatus("unit_crystal_shell", "Tortos: "..SPELL_SHIELD, TortosShields_options, true)
	settings = self.db.profile.unit_crystal_shell
end

function GridStatusTortosShields:OnStatusEnable(status)
	if status == "unit_crystal_shell" then
		self:RegisterEvent("ZONE_CHANGED", "UpdateTracking")
		self:RegisterEvent("ZONE_CHANGED_INDOORS", "UpdateTracking")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateTracking")
	end
end

function GridStatusTortosShields:OnStatusDisable(status)
	if status == "unit_crystal_shell" then
		self:Reset()
		self:UnregisterEvent("ZONE_CHANGED")
		self:UnregisterEvent("ZONE_CHANGED_INDOORS")
		self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	end
end

function GridStatusTortosShields:Reset()
	self.super.Reset(self)
	
	for guid, unitid in GridRoster:IterateRoster() do
		self.core:SendStatusLost(guid, "unit_crystal_shell")
	end
	
	self:UnregisterMessage("Grid_RosterUpdated")
	self:UnregisterEvent("UNIT_MAXHEALTH")
	self:UnregisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
	tracking = false
	
	unitHasShield = {}
end

function GridStatusTortosShields:UpdateAllUnits()
	for guid, unitid in GridRoster:IterateRoster() do
		self:UpdateUnitShield(unitid)
	end
end

function GridStatusTortosShields:UpdateTracking()
	local should_track = (GetMapInfo() == "ThunderKingRaid")
	if should_track ~= tracking then
		if tracking then
			-- Ends tracking
			--print("Tortos Shield: stop tracking")
			self:Reset()
		else
			-- Start tracking
			--print("Tortos Shield: start tracking")
			self:RegisterMessage("Grid_RosterUpdated", "UpdateAllUnits")
			self:RegisterEvent("UNIT_MAXHEALTH", "UpdateUnit")
			self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", "UpdateUnit")
			self:UpdateAllUnits()
		end
		tracking = should_track
	end
end

function GridStatusTortosShields:UpdateUnit(_, unitid)
	self:UpdateUnitShield(unitid)
end

function GridStatusTortosShields:UpdateUnitShield(unitid)
	local shield = select(15, UnitDebuff(unitid, SPELL_SHIELD))
	local guid = UnitGUID(unitid)
	
	if not shield then
		if unitHasShield[guid] then
			unitHasShield[guid] = nil
			self.core:SendStatusLost(guid, "unit_crystal_shell")
		end
		return
	elseif not unitHasShield[guid] then
		unitHasShield[guid] = true
	end
	
	local shieldFull = UnitDebuff(unitid, SPELL_SHIELD_FULL)
	local maxShield = UnitHealthMax(unitid) * 0.75

	self.core:SendStatusGained(
		guid,
		"unit_crystal_shell",
		settings.priority,
		nil,
		shieldFull and settings.colorFull or settings.color,
		tostring(shield),
		shield,
		maxShield,
		shieldFull and "Interface\\Icons\\inv_datacrystal08" or "Interface\\Icons\\INV_DataCrystal01",
		nil,
		nil,
		math.floor(shield / maxShield)
	)
end
