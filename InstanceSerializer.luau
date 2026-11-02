--!optimize 2
--!native
--!forked from SynSaveInstance

local game = game
local type = type
local typeof = typeof
local table= table
local math = math
local bit32 = bit32
local buffer = buffer

local arrayToDict
arrayToDict = function(t, mixedMode, valueOverride, typeStrict)
	local tmp = {}

	if mixedMode then
		for any1, any2 in t do
			if type(any1) == "number" then
				tmp[any2] = valueOverride or true
			elseif type(any2) == "table" then
				tmp[any1] = arrayToDict(any2, mixedMode)
			else
				tmp[any1] = any2
			end
		end
	else
		for _, key in t do
			if not typeStrict or typeStrict and type(key) == typeStrict then
				tmp[key] = true
			end
		end
	end

	return tmp
end

local Players = game:FindFirstChildOfClass("Players")
local StarterGui = game:FindFirstChildOfClass("StarterGui")
local StarterPlayer = game:FindFirstChildOfClass("StarterPlayer")
local GuiService = game:FindFirstChildOfClass("GuiService")
local RunService = game:FindFirstChildOfClass("RunService")
local UserInputService = game:FindFirstChildOfClass("UserInputService")
local MarketplaceService = game:FindFirstChildOfClass("MarketplaceService")
local HttpService = game:FindFirstChildOfClass("HttpService")
local CollectionService = game:FindFirstChildOfClass("CollectionService")
local EncodingService = game:FindFirstChildOfClass("EncodingService")
local ReflectionService = game:FindFirstChildOfClass("ReflectionService")
local UGCValidationService = game:FindFirstChildOfClass("UGCValidationService")

local StreamBuffer = {}
StreamBuffer.__index = StreamBuffer
do
	local DEFAULT_CAPACITY = 4096
	
	function StreamBuffer.new(initialCapacity)
		local cap = initialCapacity or DEFAULT_CAPACITY
		return setmetatable({
			buf = buffer.create(cap),
			len = 0,
			cap = cap,
		}, StreamBuffer)
	end
	
	function StreamBuffer:reserve(extra)
		local needed = self.len + extra
		if needed <= self.cap then
			return
		end
	
		local newCap = self.cap
		while newCap < needed do
			newCap *= 2
		end
	
		local newBuf = buffer.create(newCap)
		buffer.copy(newBuf, 0, self.buf, 0, self.len)
	
		self.buf = newBuf
		self.cap = newCap
	end
	
	function StreamBuffer:allocRegion(size)
		self:reserve(size)
		local base = self.len
		self.len += size
		return base
	end
	
	function StreamBuffer:writeu8(v)
		self:reserve(1)
		buffer.writeu8(self.buf, self.len, v)
		self.len += 1
	end
	
	function StreamBuffer:writeu16(v)
		self:reserve(2)
		buffer.writeu16(self.buf, self.len, v)
		self.len += 2
	end
	
	function StreamBuffer:writei16(v)
		self:reserve(2)
		buffer.writei16(self.buf, self.len, v)
		self.len += 2
	end
	
	function StreamBuffer:writeu32(v)
		self:reserve(4)
		buffer.writeu32(self.buf, self.len, v)
		self.len += 4
	end
	
	function StreamBuffer:writei32(v)
		self:reserve(4)
		buffer.writei32(self.buf, self.len, v)
		self.len += 4
	end
	
	function StreamBuffer:writef32(v)
		self:reserve(4)
		buffer.writef32(self.buf, self.len, v)
		self.len += 4
	end
	
	function StreamBuffer:writef64(v)
		self:reserve(8)
		buffer.writef64(self.buf, self.len, v)
		self.len += 8
	end
	
	function StreamBuffer:writestring(s)
		local n = #s
		self:reserve(n)
		buffer.writestring(self.buf, self.len, s)
		self.len += n
	end
	
	function StreamBuffer:writeLenString(s)
		self:writeu32(#s)
		self:writestring(s)
	end
	
	function StreamBuffer:fill(value, count)
		self:reserve(count)
		buffer.fill(self.buf, self.len, value, count)
		self.len += count
	end
	
	function StreamBuffer:pokeu8(offset, v)
		buffer.writeu8(self.buf, offset, v)
	end
	
	function StreamBuffer:tostring()
		return buffer.readstring(self.buf, 0, self.len)
	end
end

local gethiddenproperty = gethiddenproperty

local appendfile = appendfile
local isfile = isfile
local readfile = readfile
local writefile = writefile

local base64encode = base64encode or function(b)
	return buffer.tostring(EncodingService:Base64Encode(type(b) == "string" and buffer.fromstring(b) or b))
end
local base64decode = base64decode or function(b)
	return buffer.tostring(EncodingService:Base64Decode(type(b) == "string" and buffer.fromstring(b) or b))
end


local sharedStringId = 1e15
local sharedStrings = setmetatable({}, {
	__index = function(self, str)
		local id = base64encode(tostring(sharedStringId))
		sharedStringId += 1

		self[str] = id
		return id
	end,
})

local inheritedProperties = {}
local defaultInstances = {}

local index = function(self, index_name)
	return self[index_name]
end

local FULL_VERSION

if not pcall(function()
	FULL_VERSION = version()
end) then
	if not pcall(function()
		FULL_VERSION = settings():GetService("DebugSettings").RobloxVersion
	end) then
		if not pcall(function()
			FULL_VERSION = RunService:GetRobloxVersion()
		end) then
			FULL_VERSION = "UNKNOWN"
		end
	end
end

local CLIENT_VERSION = tonumber(string.match(FULL_VERSION, "%d+%.(%d+)")) or 9e9
local __BREAK = `__BREAK{HttpService:GenerateGUID(false)}`
local USSI_FOLDER = "ussi_cache/"

pcall(function()
	makefolder(USSI_FOLDER)
end)

local REFLECTION_FILTER = {
	Security = SecurityCapabilities.new(unpack(Enum.SecurityCapability:GetEnumItems())),
	ExcludeDisplay = true,
	ExcludeInherited = true,
}

local Type_Ids = {
	["string"] = 1,
	["bool"] = 2,
	["int"] = 3,
	["float"] = 4,
	["double"] = 5,
	["UDim"] = 6,
	["UDim2"] = 7,
	["Ray"] = 8,
	["Faces"] = 9,
	["Axes"] = 10,
	["BrickColor"] = 11,
	["Color3"] = 12,
	["Vector2"] = 13,
	["Vector3"] = 14,
	["Vector2int16"] = 15,
	["CFrame"] = 16,

	["Enum"] = 18,
	["Referent"] = 19,
	["Vector3int16"] = 20,
	["NumberSequence"] = 21,
	["ColorSequence"] = 22,
	["NumberRange"] = 23,
	["Rect"] = 24,
	["PhysicalProperties"] = 25,
	["Color3uint8"] = 26,
	["int64"] = 27,
	["SharedString"] = 28,

	["OptionalCoordinateFrame"] = 30,
	["UniqueId"] = 31,
	["Font"] = 32,
	["SecurityCapabilities"] = 33,
	["Content"] = 34,

}

local Attribute_Type_Ids =
	{
		["nil"] = 0x01,
		string = 0x02,
		boolean = 0x03,
		int32 = 0x04,

		number = 0x06,
		ValueArray = 0x07,
		ValueTable = 0x08,
		UDim = 0x09,
		UDim2 = 0x0A,
		Ray = 0x0B,
		Faces = 0x0C,
		Axes = 0x0D,
		BrickColor = 0x0E,
		Color3 = 0x0F,
		Vector2 = 0x10,
		Vector3 = 0x11,
		Vector2int16 = 0x12,
		Vector3int16 = 0x13,
		CFrame = 0x14,
		EnumItem = 0x15,

		NumberSequence = 0x17,
		NumberSequenceKeypoint = 0x18,
		ColorSequence = 0x19,
		ColorSequenceKeypoint = 0x1A,
		NumberRange = 0x1B,
		Rect = 0x1C,
		PhysicalProperties = 0x1D,
		Color3uint8 = 0x1E,
		Region3 = 0x1F,
		Region3int16 = 0x20,
		Font = 0x21,
		SecurityCapabilities = 0x22,
		Path2DControlPoint = 0x23,
		TweenInfo = 0x24,

	}

local CFrame_Rotation_Ids = {
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x02,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x03,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x05,
	["\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x06,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x07,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x09,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x0a,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x0c,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0d,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0e,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x10,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128"] = 0x11,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x14,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128"] = 0x15,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x17,
	["\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128"] = 0x18,
	["\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x19,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x1b,
	["\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x1c,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x1e,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x1f,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x20,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x22,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128"] = 0x23,
}
local rotationBuffer = buffer.create(36)
local bf32_rotation = buffer.writef32

local rawBasisString = function(r00, r01, r02, r10, r11, r12, r20, r21, r22)
	bf32_rotation(rotationBuffer, 0, r00)
	bf32_rotation(rotationBuffer, 4, r01)
	bf32_rotation(rotationBuffer, 8, r02)
	bf32_rotation(rotationBuffer, 12, r10)
	bf32_rotation(rotationBuffer, 16, r11)
	bf32_rotation(rotationBuffer, 20, r12)
	bf32_rotation(rotationBuffer, 24, r20)
	bf32_rotation(rotationBuffer, 28, r21)
	bf32_rotation(rotationBuffer, 32, r22)
	return buffer.tostring(rotationBuffer)
end

local EMPTY_BUFFER = buffer.create(0)
local BASE_CAPABILITIES = SecurityCapabilities.new()
local CAPABILITY_BITS = {
	Plugin = 0,
	LocalUser = 1,
	WritePlayer = 2,
	RobloxScript = 3,
	RobloxEngine = 4,
	NotAccessible = 5,
	RunClientScript = 8,
	RunServerScript = 9,
	AccessOutsideWrite = 11,
	Unassigned = 15,
	LoadUnownedAsset = 16,
	LoadString = 17,
	ScriptGlobals = 18,
	CreateInstances = 19,
	Basic = 20,
	Audio = 21,
	DataStore = 22,
	Network = 23,
	Physics = 24,
	UI = 25,
	CSG = 26,
	Chat = 27,
	Animation = 28,
	AvatarAppearance = 29,
	Input = 30,
	Environment = 31,

	RemoteEvent = 32,
	LegacySound = 33,
	Players = 34,
	CapabilityControl = 35,
	AssetRead = 36,
	AssetManagement = 37,
	DynamicGeneration = 38,
	PlatformAvatarEditing = 39,
	AssetCreateUpdate = 40,
	Capture = 41,
	SensitiveInput = 42,
	Monetization = 43,
	LoadOwnedAsset = 44,
	Social = 45,
	ServerCommunication = 46,
	Logging = 47,
	PromptExternalPurchase = 48,
	Groups = 49,
	Teleport = 50,
	Consequences = 51,
	Material = 52,
	AvatarBehavior = 53,
	RemoteCommand = 59,
	InternalTest = 60,
	PluginOrOpenCloud = 61,
	Assistant = 62,
	Restricted = 63,
}

local capabilityHalves = function(raw)
	local rawString = tostring(raw)
	if rawString == "" then
		return 0, 0
	end

	local lo, hi = 0, 0
	for _, flag in string.split(rawString, " | ") do
		local b = CAPABILITY_BITS[flag]
		if b then
			if b < 32 then
				lo = bit32.bor(lo, bit32.lshift(1, b))
			else
				hi = bit32.bor(hi, bit32.lshift(1, b - 32))
			end
		end
	end
	return lo, hi
end

local capabilityNumber = function(raw)
	local lo, hi = capabilityHalves(raw)
	return hi * 0x100000000 + lo
end

local countBits = function(...)
	local Value = 0

	for i, bit in { ... } do
		if bit then
			Value += 2 ^ (i - 1)
		end
	end

	return Value
end

local cframeToQuaternion = function(cframe)
	local _, _, _, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cframe:GetComponents()
	local trace = R00 + R11 + R22
	local S, qW, qX, qY, qZ
	if trace > 0 then
		S = math.sqrt(1 + trace) * 2
		qW = 0.25 * S
		qX = (R21 - R12) / S
		qY = (R02 - R20) / S
		qZ = (R10 - R01) / S
	elseif (R00 > R11) and (R00 > R22) then
		S = math.sqrt(1 + R00 - R11 - R22) * 2
		qW = (R21 - R12) / S
		qX = 0.25 * S
		qY = (R01 + R10) / S
		qZ = (R02 + R20) / S
	elseif R11 > R22 then
		S = math.sqrt(1 + R11 - R00 - R22) * 2
		qW = (R02 - R20) / S
		qX = (R01 + R10) / S
		qY = 0.25 * S
		qZ = (R12 + R21) / S
	else
		S = math.sqrt(1 + R22 - R00 - R11) * 2
		qW = (R10 - R01) / S
		qX = (R02 + R20) / S
		qY = (R12 + R21) / S
		qZ = 0.25 * S
	end

	if qW < 0 then
		qW, qX, qY, qZ = -qW, -qX, -qY, -qZ
	end
	return qX, qY, qZ, qW
end

local classifyTable = function(t)
	local len = #t
	if len == 0 then
		len = nil
	end
	if next(t, len) == nil then
		return "ValueArray"
	else
		return "ValueTable"
	end
end

local resolveTypeName = function(value)
	local t = typeof(value)
	if t == "table" then
		return classifyTable(value)
	end
	return t
end

local scratch = buffer.create(8)

local bf32, ru32 = buffer.writef32, buffer.readu32
local lr32 = bit32.lrotate

local rotf = function(v)
	bf32(scratch, 0, v)
	return lr32(ru32(scratch, 0), 1)
end

local zigzag32 = function(v)
	return (v < 0) and (2 * -v - 1) or (2 * v)
end

local splitU64 = function(v)
	local hi = v // 4294967296
	return hi, v - hi * 4294967296
end

local zigzag64 = function(v)
	local neg = v < 0
	local hi, lo = splitU64(neg and -v or v)

	local carry = bit32.extract(lo, 31)
	lo = bit32.lshift(lo, 1)
	hi = bit32.bor(bit32.lshift(hi, 1), carry)

	if neg then
		if lo == 0 then
			lo, hi = 0xFFFFFFFF, hi - 1
		else
			lo -= 1
		end
	end
	return hi, lo
end

local zigzagHalves = function(hi, lo)
	local sign = bit32.extract(hi, 31)
	local shi = bit32.bor(bit32.lshift(hi, 1), bit32.extract(lo, 31))
	local slo = bit32.lshift(lo, 1)
	if sign == 1 then
		shi, slo = bit32.bnot(shi), bit32.bnot(slo)
	end
	return shi, slo
end

local u32FromHex = function(hex, at)
	return tonumber(string.sub(hex, at, at + 7), 16)
end

local pokeU32Planes = function(sbuf, o, n, v)
	local buf = sbuf.buf
	local wu8 = buffer.writeu8
	local rshift = bit32.rshift
	wu8(buf, o, rshift(v, 24))
	wu8(buf, o + n, rshift(v, 16))
	wu8(buf, o + 2 * n, rshift(v, 8))
	wu8(buf, o + 3 * n, v)
end

local pokeU64Planes = function(sbuf, o, n, hi, lo)
	pokeU32Planes(sbuf, o, n, hi)
	pokeU32Planes(sbuf, o + 4 * n, n, lo)
end

local interleavedU32Plane = function(sbuf, n, base, getU32ForIndex)
	local buf = sbuf.buf
	local rshift = bit32.rshift
	local wu8 = buffer.writeu8
	for i = 1, n do
		local v = getU32ForIndex(i)
		local o = base + (i - 1)
		wu8(buf, o, rshift(v, 24))
		wu8(buf, o + n, rshift(v, 16))
		wu8(buf, o + 2 * n, rshift(v, 8))
		wu8(buf, o + 3 * n, v)
	end
end

local writeRefPlane = function(sbuf, n, base, getRef)
	local buf = sbuf.buf
	local rshift = bit32.rshift
	local wu8 = buffer.writeu8
	local lastRef = nil
	for i = 1, n do
		local ref = getRef(i)
		local acc = lastRef and (ref - lastRef) or ref
		lastRef = ref
		local v = zigzag32(acc)
		local o = base + (i - 1)
		wu8(buf, o, rshift(v, 24))
		wu8(buf, o + n, rshift(v, 16))
		wu8(buf, o + 2 * n, rshift(v, 8))
		wu8(buf, o + 3 * n, v)
	end
end

local planeEncoder = function(...)
	local getters = { ... }
	local k = #getters
	local rshift = bit32.rshift
	local wu8 = buffer.writeu8
	return function(sbuf, vals, n)
		local base = sbuf:allocRegion(4 * k * n)
		local buf = sbuf.buf
		local stride = 4 * n
		for p = 1, k do
			local getter = getters[p]
			local pbase = base + (p - 1) * stride
			for i = 1, n do
				local v = getter(vals[i])
				local o = pbase + (i - 1)
				wu8(buf, o, rshift(v, 24))
				wu8(buf, o + n, rshift(v, 16))
				wu8(buf, o + 2 * n, rshift(v, 8))
				wu8(buf, o + 3 * n, v)
			end
		end
	end
end

local f32Encoder = function(...)
	local paths = { ... }
	local k = #paths
	local wf32 = buffer.writef32
	return function(sbuf, vals, n)
		local base = sbuf:allocRegion(4 * k * n)
		local buf = sbuf.buf
		for i = 1, n do
			local v = vals[i]
			local o = base + (i - 1) * 4 * k
			for p = 1, k do
				wf32(buf, o, paths[p](v))
				o += 4
			end
		end
	end
end

local i16Encoder = function(...)
	local comps = { ... }
	local k = #comps
	local wi16 = buffer.writei16
	return function(sbuf, vals, n)
		local base = sbuf:allocRegion(2 * k * n)
		local buf = sbuf.buf
		for i = 1, n do
			local v = vals[i]
			local o = base + (i - 1) * 2 * k
			for p = 1, k do
				wi16(buf, o, v[comps[p]])
				o += 2
			end
		end
	end
end

local flagEncoder = function(bits)
	return function(sbuf, vals, n)
		local base = sbuf:allocRegion(n)
		local buf = sbuf.buf
		local wu8 = buffer.writeu8
		for i = 1, n do
			local v = vals[i]
			local packed = 0
			for name, b in bits do
				if v[name] then
					packed += b
				end
			end
			wu8(buf, base + (i - 1), packed)
		end
	end
end

local writeCFrameBody = function(sbuf, vals, n, optional)
	local coordsX, coordsY, coordsZ = table.create(n), table.create(n), table.create(n)
	local wu8, wstr = sbuf.writeu8, sbuf.writestring
	local identity = CFrame.identity

	for i = 1, n do
		local val = vals[i]

		if optional then
			if val == nil then
				val = identity
			end
		end

		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = val:GetComponents()
		coordsX[i], coordsY[i], coordsZ[i] = x, y, z

		local rotStr = rawBasisString(r00, r01, r02, r10, r11, r12, r20, r21, r22)
		local id = CFrame_Rotation_Ids[rotStr]
		if id then
			wu8(sbuf, id)
		else
			wu8(sbuf, 0)
			wstr(sbuf, rotStr)
		end
	end

	local posBase = sbuf:allocRegion(12 * n)
	local planes = { coordsX, coordsY, coordsZ }
	local cbuf = sbuf.buf
	local lr, rshift = bit32.lrotate, bit32.rshift
	local bf32, ru32, bwu8 = buffer.writef32, buffer.readu32, buffer.writeu8
	for p = 1, 3 do
		local coords = planes[p]
		local pbase = posBase + (p - 1) * 4 * n
		for i = 1, n do
			bf32(scratch, 0, coords[i])
			local v = lr(ru32(scratch, 0), 1)
			local o = pbase + (i - 1)
			bwu8(cbuf, o, rshift(v, 24))
			bwu8(cbuf, o + n, rshift(v, 16))
			bwu8(cbuf, o + 2 * n, rshift(v, 8))
			bwu8(cbuf, o + 3 * n, v)
		end
	end
end

local Attribute_Encoders
Attribute_Encoders = {
	_packMultiple = function(encoder, value1, value2, value3)
		local buf1, size1 = encoder(value1)
		local buf2, size2 = encoder(value2)

		local len = size1 + size2
		local buf3, size3

		if value3 ~= nil then
			buf3, size3 = encoder(value3)
			len += size3
		end

		local b = buffer.create(len)

		buffer.copy(b, 0, buf1)
		buffer.copy(b, size1, buf2)

		if value3 ~= nil then
			buffer.copy(b, size1 + size2, buf3)
		end

		return b, len
	end,
	_makeSequence = function(keypoint_handler, keypointSize)
		return function(raw)
			local keypoints = raw.Keypoints
			local n = #keypoints

			local len = 4 + keypointSize * n
			local b = buffer.create(len)

			buffer.writeu32(b, 0, n)

			local offset = 4
			for _, keypoint in keypoints do
				keypoint_handler(keypoint, b, offset)
				offset += keypointSize
			end

			return b, len
		end
	end,
	_writeI64LE = function(b, offset, raw)
		local low = bit32.band(raw, 0xFFFFFFFF)
		local high = (raw - low) / 0x100000000

		buffer.writei32(b, offset, low)
		buffer.writei32(b, offset + 4, high)
	end,
	_packF32 = nil,
	_packI16 = nil,
	_makeVectorPacker = function(writeFunc, elementSize)
		return function(X, Y, Z)
			local len = Z and (elementSize * 3) or (elementSize * 2)
			local b = buffer.create(len)

			writeFunc(b, 0, X)
			writeFunc(b, elementSize, Y)
			if Z then
				writeFunc(b, elementSize * 2, Z)
			end

			return b, len
		end
	end,

	["nil"] = function(raw)
		return EMPTY_BUFFER, 0
	end,
	["string"] = function(raw)
		local raw_len = #raw
		local len = 4 + raw_len

		local b = buffer.create(len)

		buffer.writeu32(b, 0, raw_len)
		buffer.writestring(b, 4, raw)

		return b, len
	end,
	["boolean"] = function(raw)
		local b = buffer.create(1)

		buffer.writeu8(b, 0, raw and 1 or 0)

		return b, 1
	end,
	["number"] = function(raw)
		local b = buffer.create(8)

		buffer.writef64(b, 0, raw)

		return b, 8
	end,
	["ValueArray"] = function(raw)

		local n = 0
		for k in raw do
			if type(k) == "number" and k > n and k == math.floor(k) and k >= 1 then
				n = k
			end
		end

		local bufs = table.create(n)
		local len = 4
		local count = 0

		for i = 1, n do
			local value = raw[i]
			local b, size

			if value == nil then

				b = buffer.create(1)
				buffer.writeu8(b, 0, 0x01)
				size = 1
			else
				local valueTypeName = resolveTypeName(value)
				local typeId = Attribute_Type_Ids[valueTypeName]
				local descriptor = Attribute_Encoders[valueTypeName]
				if not descriptor then
					continue
				end
				local dataBuf, dataSize = descriptor(value)

				b = buffer.create(1 + dataSize)
				buffer.writeu8(b, 0, typeId)
				buffer.copy(b, 1, dataBuf)
				size = 1 + dataSize
			end

			count += 1
			bufs[count] = b
			len += size
		end

		local b = buffer.create(len)
		buffer.writeu32(b, 0, count)

		local offset = 4
		for i = 1, count do
			local bb = bufs[i]
			buffer.copy(b, offset, bb)
			offset += buffer.len(bb)
		end

		return b, len
	end,
	["ValueTable"] = function(raw)
		local keys = {}
		local keyMap = {}
		local n = 0

		for k in raw do
			n += 1
			local keyStr = tostring(k)
			keys[n] = keyStr
			keyMap[keyStr] = k
		end

		table.sort(keys)

		local bufs = table.create(n)
		local len = 4
		local count = 0

		for i = 1, n do
			local keyStr = keys[i]
			local value = raw[keyMap[keyStr]]

			local valueTypeName = resolveTypeName(value)
			local typeId = Attribute_Type_Ids[valueTypeName]
			local descriptor = Attribute_Encoders[valueTypeName]
			if not descriptor then
				continue
			end
			local dataBuf, dataSize = descriptor(value)

			local keyLen = #keyStr
			local size = 4 + keyLen + 1 + dataSize
			local b = buffer.create(size)

			buffer.writeu32(b, 0, keyLen)
			buffer.writestring(b, 4, keyStr)
			buffer.writeu8(b, 4 + keyLen, typeId)
			buffer.copy(b, 4 + keyLen + 1, dataBuf)

			count += 1
			bufs[count] = b
			len += size
		end

		local b = buffer.create(len)
		buffer.writeu32(b, 0, count)

		local offset = 4
		for i = 1, count do
			local bb = bufs[i]
			buffer.copy(b, offset, bb)
			offset += buffer.len(bb)
		end

		return b, len
	end,
	["UDim"] = function(raw)
		local b = buffer.create(8)

		buffer.writef32(b, 0, raw.Scale)
		buffer.writei32(b, 4, raw.Offset)

		return b, 8
	end,
	["UDim2"] = function(raw)
		return Attribute_Encoders._packMultiple(Attribute_Encoders["UDim"], raw.X, raw.Y)
	end,
	["Ray"] = function(raw)
		return Attribute_Encoders._packMultiple(Attribute_Encoders["Vector3"], raw.Origin, raw.Direction)
	end,
	["Faces"] = function(raw)
		local b = buffer.create(4)

		buffer.writeu32(b, 0, countBits(raw.Right, raw.Top, raw.Back, raw.Left, raw.Bottom, raw.Front))

		return b, 4
	end,
	["Axes"] = function(raw)
		local b = buffer.create(4)

		buffer.writeu32(b, 0, countBits(raw.X, raw.Y, raw.Z))

		return b, 4
	end,
	["BrickColor"] = function(raw)
		local b = buffer.create(4)

		buffer.writeu32(b, 0, raw.Number)

		return b, 4
	end,
	["Color3"] = function(raw)
		return Attribute_Encoders._packF32(raw.R, raw.G, raw.B)
	end,
	["Vector2"] = function(raw)
		return Attribute_Encoders._packF32(raw.X, raw.Y)
	end,
	["Vector3"] = function(raw)
		return Attribute_Encoders._packF32(raw.X, raw.Y, raw.Z)
	end,
	["Vector2int16"] = function(raw)
		return Attribute_Encoders._packI16(raw.X, raw.Y)
	end,
	["Vector3int16"] = function(raw)
		return Attribute_Encoders._packI16(raw.X, raw.Y, raw.Z)
	end,
	["CFrame"] = function(raw)
		local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = raw:GetComponents()

		local rotation_ID = CFrame_Rotation_Ids[rawBasisString(R00, R01, R02, R10, R11, R12, R20, R21, R22)]

		local len = rotation_ID and 13 or 49
		local b = buffer.create(len)

		local _packF32 = Attribute_Encoders._packF32
		local position = _packF32(X, Y, Z)
		buffer.copy(b, 0, position)

		if rotation_ID then
			buffer.writeu8(b, 12, rotation_ID)
		else
			buffer.writeu8(b, 12, 0x0)

			local xBasis = _packF32(R00, R01, R02)
			buffer.copy(b, 13, xBasis)
			local yBasis = _packF32(R10, R11, R12)
			buffer.copy(b, 13 + 12, yBasis)
			local zBasis = _packF32(R20, R21, R22)
			buffer.copy(b, 13 + 24, zBasis)
		end

		return b, len
	end,
	["EnumItem"] = function(raw)
		local nameBuf, nameSize = Attribute_Encoders["string"](tostring(raw.EnumType))

		local len = nameSize + 4
		local b = buffer.create(len)

		buffer.copy(b, 0, nameBuf)
		buffer.writeu32(b, nameSize, raw.Value)

		return b, len
	end,
	["NumberSequence"] = nil,
	["NumberSequenceKeypoint"] = function(keypoint, b, offset)
		if not b then
			return Attribute_Encoders._packF32(keypoint.Envelope, keypoint.Time, keypoint.Value)
		end

		buffer.writef32(b, offset, keypoint.Envelope)
		offset += 4
		buffer.writef32(b, offset, keypoint.Time)
		offset += 4
		buffer.writef32(b, offset, keypoint.Value)
	end,
	["ColorSequence"] = nil,
	["ColorSequenceKeypoint"] = function(keypoint, b, offset)
		local value = Attribute_Encoders["Color3"](keypoint.Value)

		if not b then
			b = buffer.create(20)
			offset = 0
		end

		buffer.writef32(b, offset, 0)
		offset += 4
		buffer.writef32(b, offset, keypoint.Time)
		offset += 4
		buffer.copy(b, offset, value)

		return b, 20
	end,
	["NumberRange"] = function(raw)
		return Attribute_Encoders._packF32(raw.Min, raw.Max)
	end,
	["Rect"] = function(raw)
		return Attribute_Encoders._packMultiple(Attribute_Encoders["Vector2"], raw.Min, raw.Max)
	end,
	["PhysicalProperties"] = function(raw)
		local b = buffer.create(25)

		buffer.writeu8(b, 0, 1)

		buffer.writef32(b, 1, raw.Density)
		buffer.writef32(b, 5, raw.Friction)
		buffer.writef32(b, 9, raw.Elasticity)
		buffer.writef32(b, 13, raw.FrictionWeight)
		buffer.writef32(b, 17, raw.ElasticityWeight)
		buffer.writef32(b, 21, raw.AcousticAbsorption)

		return b, 25
	end,
	["Color3uint8"] = function(raw)
		local b = buffer.create(3)

		buffer.writeu8(b, 0, math.floor(raw.R * 255))
		buffer.writeu8(b, 1, math.floor(raw.G * 255))
		buffer.writeu8(b, 2, math.floor(raw.B * 255))

		return b, 3
	end,
	["Region3"] = function(raw)
		local Translation = raw.CFrame.Position
		local HalfSize = raw.Size * 0.5

		return Attribute_Encoders._packMultiple(
			Attribute_Encoders["Vector3"],
			Translation - HalfSize,
			Translation + HalfSize
		)
	end,
	["Region3int16"] = function(raw)
		return Attribute_Encoders._packMultiple(Attribute_Encoders["Vector3int16"], raw.Min, raw.Max)
	end,
	["Font"] = function(raw)
		local encoder = Attribute_Encoders["string"]

		local familyBuf, familySize = encoder(raw.Family)
		local faceIdBuf, faceIdSize = encoder("")

		local len = 3 + familySize + faceIdSize
		local b = buffer.create(len)

		local hasWeight, weight = pcall(index, raw, "Weight")
		local hasStyle, style = pcall(index, raw, "Style")

		buffer.writeu16(b, 0, hasWeight and weight.Value or 0)
		buffer.writeu8(b, 2, hasStyle and style.Value or 0)

		buffer.copy(b, 3, familyBuf)
		buffer.copy(b, 3 + familySize, faceIdBuf)

		return b, len
	end,
	["SecurityCapabilities"] = function(raw)
		local b = buffer.create(8)

		if raw == BASE_CAPABILITIES then
			return b, 8
		end

		Attribute_Encoders._writeI64LE(b, 0, capabilityNumber(raw))

		return b, 8
	end,
	["Path2DControlPoint"] = function(raw)
		return Attribute_Encoders._packMultiple(
			Attribute_Encoders["UDim2"],
			raw.Position,
			raw.LeftTangent,
			raw.RightTangent
		)
	end,
	["TweenInfo"] = function(raw)
		local b = buffer.create(21)

		buffer.writef32(b, 0, raw.Time)
		buffer.writef32(b, 4, raw.DelayTime)
		buffer.writei32(b, 8, raw.RepeatCount)
		buffer.writeu32(b, 12, raw.EasingStyle.Value)
		buffer.writeu32(b, 16, raw.EasingDirection.Value)
		buffer.writeu8(b, 20, raw.Reverses and 1 or 0)

		return b, 21
	end,
}

do
	Attribute_Encoders["NumberSequence"] =
		Attribute_Encoders._makeSequence(Attribute_Encoders["NumberSequenceKeypoint"], 12)

	Attribute_Encoders["ColorSequence"] =
		Attribute_Encoders._makeSequence(Attribute_Encoders["ColorSequenceKeypoint"], 20)
end

do
	Attribute_Encoders._packF32 = Attribute_Encoders._makeVectorPacker(buffer.writef32, 4)

	Attribute_Encoders._packI16 = Attribute_Encoders._makeVectorPacker(buffer.writei16, 2)
end

local Binary_Encoders = {
	["string"] = function(sbuf, vals, n)
		local total = 4 * n
		for i = 1, n do
			total += #vals[i]
		end
		local o = sbuf:allocRegion(total)
		local buf = sbuf.buf
		local wu32, wstr = buffer.writeu32, buffer.writestring
		for i = 1, n do
			local v = vals[i]
			local l = #v
			wu32(buf, o, l)
			wstr(buf, o + 4, v)
			o += 4 + l
		end
	end,
	["bool"] = function(sbuf, vals, n)
		local base = sbuf:allocRegion(n)
		local buf = sbuf.buf
		local wu8 = buffer.writeu8
		for i = 1, n do
			if vals[i] then
				wu8(buf, base + (i - 1), 1)
			end
		end
	end,

	["int"] = planeEncoder(zigzag32),
	["float"] = planeEncoder(rotf),

	["double"] = function(sbuf, vals, n)
		local base = sbuf:allocRegion(8 * n)
		local buf = sbuf.buf
		local wf64 = buffer.writef64
		for i = 1, n do
			wf64(buf, base + (i - 1) * 8, vals[i])
		end
	end,

	["UDim"] = planeEncoder(function(v)
		return rotf(v.Scale)
	end, function(v)
		return zigzag32(v.Offset)
	end),

	["UDim2"] = planeEncoder(function(v)
		return rotf(v.X.Scale)
	end, function(v)
		return rotf(v.Y.Scale)
	end, function(v)
		return zigzag32(v.X.Offset)
	end, function(v)
		return zigzag32(v.Y.Offset)
	end),

	["Ray"] = f32Encoder(function(v)
		return v.Origin.X
	end, function(v)
		return v.Origin.Y
	end, function(v)
		return v.Origin.Z
	end, function(v)
		return v.Direction.X
	end, function(v)
		return v.Direction.Y
	end, function(v)
		return v.Direction.Z
	end),

	["Faces"] = flagEncoder({ Right = 1, Top = 2, Back = 4, Left = 8, Bottom = 16, Front = 32 }),
	["Axes"] = flagEncoder({ X = 1, Y = 2, Z = 4 }),

	["BrickColor"] = planeEncoder(function(v)
		return v.Number
	end),

	["Color3"] = planeEncoder(function(v)
		return rotf(v.R)
	end, function(v)
		return rotf(v.G)
	end, function(v)
		return rotf(v.B)
	end),
	["Vector2"] = planeEncoder(function(v)
		return rotf(v.X)
	end, function(v)
		return rotf(v.Y)
	end),
	["Vector3"] = planeEncoder(function(v)
		return rotf(v.X)
	end, function(v)
		return rotf(v.Y)
	end, function(v)
		return rotf(v.Z)
	end),
	["Vector2int16"] = i16Encoder("X", "Y"),

	["CFrame"] = function(sbuf, vals, n)
		writeCFrameBody(sbuf, vals, n, nil)
	end,

	["Enum"] = planeEncoder(function(v)
		return v.Value
	end),

	["Referent"] = function(sbuf, vals, n, refs)
		writeRefPlane(sbuf, n, sbuf:allocRegion(4 * n), function(i)
			local val = vals[i]
			return (val and refs[val]) or -1
		end)
	end,

	["Vector3int16"] = i16Encoder("X", "Y", "Z"),

	["NumberSequence"] = function(sbuf, vals, n)
		local total = 4 * n
		for i = 1, n do
			total += 12 * #vals[i].Keypoints
		end
		local o = sbuf:allocRegion(total)
		local buf = sbuf.buf
		local wu32, wf32 = buffer.writeu32, buffer.writef32
		for i = 1, n do
			local keypoints = vals[i].Keypoints
			wu32(buf, o, #keypoints)
			o += 4
			for _, kp in keypoints do
				wf32(buf, o, kp.Time)
				wf32(buf, o + 4, kp.Value)
				wf32(buf, o + 8, kp.Envelope)
				o += 12
			end
		end
	end,
	["ColorSequence"] = function(sbuf, vals, n)
		local total = 4 * n
		for i = 1, n do
			total += 20 * #vals[i].Keypoints
		end
		local o = sbuf:allocRegion(total)
		local buf = sbuf.buf
		local wu32, wf32 = buffer.writeu32, buffer.writef32
		for i = 1, n do
			local keypoints = vals[i].Keypoints
			wu32(buf, o, #keypoints)
			o += 4
			for _, kp in keypoints do
				local c = kp.Value
				wf32(buf, o, kp.Time)
				wf32(buf, o + 4, c.R)
				wf32(buf, o + 8, c.G)
				wf32(buf, o + 12, c.B)
				wf32(buf, o + 16, 0)
				o += 20
			end
		end
	end,

	["NumberRange"] = f32Encoder(function(v)
		return v.Min
	end, function(v)
		return v.Max
	end),

	["Rect"] = planeEncoder(function(v)
		return rotf(v.Min.X)
	end, function(v)
		return rotf(v.Min.Y)
	end, function(v)
		return rotf(v.Max.X)
	end, function(v)
		return rotf(v.Max.Y)
	end),

	["PhysicalProperties"] = function(sbuf, vals, n)
		sbuf:reserve(25 * n)
		local buf = sbuf.buf
		local o = sbuf.len
		local wu8, wf32 = buffer.writeu8, buffer.writef32
		for i = 1, n do
			local val = vals[i]
			if val then
				wu8(buf, o, 3)
				wf32(buf, o + 1, val.Density)
				wf32(buf, o + 5, val.Friction)
				wf32(buf, o + 9, val.Elasticity)
				wf32(buf, o + 13, val.FrictionWeight)
				wf32(buf, o + 17, val.ElasticityWeight)
				wf32(buf, o + 21, val.AcousticAbsorption)
				o += 25
			else
				wu8(buf, o, 0)
				o += 1
			end
		end
		sbuf.len = o
	end,

	["Color3uint8"] = function(sbuf, vals, n)
		local base = sbuf:allocRegion(3 * n)
		local buf = sbuf.buf
		local wu8 = buffer.writeu8
		local floor = math.floor
		for i = 1, n do
			local val = vals[i]
			local o = base + (i - 1)
			wu8(buf, o, floor(val.R * 255 + 0.5))
			wu8(buf, o + n, floor(val.G * 255 + 0.5))
			wu8(buf, o + 2 * n, floor(val.B * 255 + 0.5))
		end
	end,

	["int64"] = function(sbuf, vals, n)
		local base = sbuf:allocRegion(8 * n)
		for i = 1, n do
			pokeU64Planes(sbuf, base + (i - 1), n, zigzag64(vals[i]))
		end
	end,

	["SharedString"] = function(sbuf, vals, n, sstr)
		local base = sbuf:allocRegion(4 * n)
		interleavedU32Plane(sbuf, n, base, function(i)
			local content = vals[i]

			local index = sstr.hashes[content]
			if not index then
				index = sstr.count
				sstr.hashes[content] = index
				sstr.count += 1
				sstr.order[index + 1] = content
			end
			return index
		end)
	end,

	["OptionalCoordinateFrame"] = function(sbuf, vals, n)
		sbuf:writeu8(0x10)
		writeCFrameBody(sbuf, vals, n, true)

		sbuf:writeu8(0x02)
		local boolBase = sbuf:allocRegion(n)
		local buf = sbuf.buf
		local wu8 = buffer.writeu8
		for i = 1, n do
			if vals[i] ~= nil then
				wu8(buf, boolBase + (i - 1), 1)
			end
		end
	end,
	["UniqueId"] = function(sbuf, vals, n)
		local base = sbuf:allocRegion(16 * n)

		for i = 1, n do
			local val = vals[i]
			local o = base + (i - 1)
			local hex = string.gsub(val, "%-", "")
			local randHi, randLo = zigzagHalves(u32FromHex(hex, 1), u32FromHex(hex, 9))

			pokeU32Planes(sbuf, o, n, u32FromHex(hex, 25))
			pokeU32Planes(sbuf, o + 4 * n, n, u32FromHex(hex, 17))
			pokeU32Planes(sbuf, o + 8 * n, n, randHi)
			pokeU32Planes(sbuf, o + 12 * n, n, randLo)
		end
	end,
	["Font"] = function(sbuf, vals, n)
		local wlstr, wu16, wu8, wu32 = sbuf.writeLenString, sbuf.writeu16, sbuf.writeu8, sbuf.writeu32
		for i = 1, n do
			local val = vals[i]

			local hasWeight, weight = pcall(index, val, "Weight")
			local hasStyle, style = pcall(index, val, "Style")

			wlstr(sbuf, val.Family)
			wu16(sbuf, hasWeight and weight.Value or 0)
			wu8(sbuf, hasStyle and style.Value or 0)
			wu32(sbuf, 0)
		end
	end,
	["SecurityCapabilities"] = function(sbuf, vals, n)
		local base = sbuf:allocRegion(8 * n)
		for i = 1, n do
			local lo, hi = capabilityHalves(vals[i])
			pokeU64Planes(sbuf, base + (i - 1), n, zigzagHalves(hi, lo))
		end
	end,
	["Content"] = function(sbuf, vals, n)
		local uris = {}

		local base = sbuf:allocRegion(4 * n)
		interleavedU32Plane(sbuf, n, base, function(i)
			local v = vals[i]
			if v ~= nil and v.SourceType == Enum.ContentSourceType.Uri then
				table.insert(uris, v.Uri or "")
				return zigzag32(1)
			end
			return 0
		end)

		sbuf:writeu32(#uris)
		for _, uri in uris do
			sbuf:writeLenString(uri)
		end

		sbuf:writeu32(0)
		sbuf:writeu32(0)
	end,
}

for datatype, sameAs in
	{
		["NetAssetRef"] = "SharedString",
		["ContentId"] = "string",
		["BinaryString"] = "string",
		["ProtectedString"] = "string",
	}
do
	Type_Ids[datatype] = Type_Ids[sameAs]
	Binary_Encoders[datatype] = Binary_Encoders[sameAs]
end

local ESCAPES_PATTERN = "[&<>\"'\0\1-\9\11-\12\14-\31\127-\255]"

local ESCAPES = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&#34;",
	["'"] = "&#39;",
	["\0"] = "",
}

for rangeStart, rangeEnd in string.gmatch(ESCAPES_PATTERN, "(.)%-(.)") do
	for charCode = string.byte(rangeStart), string.byte(rangeEnd) do
		ESCAPES[string.char(charCode)] = `&#{charCode};`
	end
end

local ClassList, FetchAPI
do
	local ClassPropertyExceptions = arrayToDict({
		Whitelist = {},
		Blacklist = {
			BillboardGui = { "PlayerToHideFrom" },
			LuaSourceContainer = { "ScriptGuid" },
			Instance = { "UniqueId", "HistoryId", "SourceAssetId", "SourceContent" },
		},
	}, true)

	local PHYSICAL_CONFIG_BASE =
		"\67\83\71\80\72\83\8\0\0\0\2\0\40\181\47\253\32\180\149\1\0\120\0\120\32\193\32\65\65\2\12\1\3\2\1\12\193\16\160\112\242\1\176\106\234\58\123\18\99\238\29\229\253\198\101\127\68\150\204\66\96\179\97\185\59\111\222\22\115\2\106"
	local CF = Enum.CollisionFidelity

	local PHYSICAL_CONFIG_BY_CF = {
		[CF.Box] = "\67\83\71\80\72\83\0\0\0\0\66\76\79\67\75",
	}

	do
		local base = PHYSICAL_CONFIG_BASE
		local prefix = string.sub(base, 1, 10)
		local suffix = string.sub(base, 12)

		local byteMap = {
			[CF.Hull] = 1,
			[CF.Default] = 2,
			[CF.PreciseConvexDecomposition] = 3,
			[CF.Tunable] = 7,
		}

		for cf, byte in byteMap do
			PHYSICAL_CONFIG_BY_CF[cf] = `{prefix}{string.char(byte)}{suffix}`
		end
	end
	local AttributesSerialize = function(attrs, header_bytes)

		local count = 0
		local buffer_size = 4
		local sorted = {}
		local formatted = table.clone(attrs)

		if header_bytes then
			buffer_size += #header_bytes
		end

		for attr, val in attrs do
			local t = resolveTypeName(val)

			local encoder = Attribute_Encoders[t]
			if not encoder then
				continue
			end

			count += 1
			sorted[count] = attr

			local attr_size

			formatted[attr], attr_size = encoder(val)

			buffer_size += 5 + #attr + attr_size
		end

		table.sort(sorted)

		local b = buffer.create(buffer_size)

		local offset = 0

		if header_bytes then
			for _, header_byte in header_bytes do
				buffer.writeu8(b, offset, header_byte)
				offset += 1
			end
		end

		buffer.writeu32(b, offset, count)
		offset += 4

		local stringEncoder = Attribute_Encoders["string"]
		for _, attr in sorted do
			local nameBuf, nameSize = stringEncoder(attr)

			buffer.copy(b, offset, nameBuf)
			offset += nameSize

			buffer.writeu8(b, offset, Attribute_Type_Ids[resolveTypeName(attrs[attr])])
			offset += 1

			local bb = formatted[attr]

			buffer.copy(b, offset, bb)
			offset += buffer.len(bb)
		end

		return buffer.tostring(b)
	end

	local AttenuationSerialize = function(attenuations)
		if not next(attenuations) then
			return "\0"
		end

		local count = 0

		local sorted = {}

		for key in attenuations do
			count += 1
			sorted[count] = key
		end

		table.sort(sorted)

		local b = buffer.create(1 + count * 8)

		local offset = 1
		for _, key in sorted do
			buffer.writef32(b, offset, key)
			offset += 4
			buffer.writef32(b, offset, attenuations[key])
			offset += 4
		end

		return buffer.tostring(b)
	end

	local TransformsSerialize = function(transforms)
		local n = #transforms

		if n == 0 then
			return "\1\0\0\0\0\0\0\0"
		end

		local b = buffer.create(8 + n * 48)

		buffer.writeu32(b, 0, 1)
		buffer.writeu32(b, 4, n)

		local _packF32 = Attribute_Encoders._packF32

		local offset = 8
		for _, transform in transforms do
			local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = transform:GetComponents()

			local xBasis = _packF32(R00, R01, R02)
			buffer.copy(b, offset, xBasis)
			offset += 12

			local yBasis = _packF32(R10, R11, R12)
			buffer.copy(b, offset, yBasis)
			offset += 12

			local zBasis = _packF32(R20, R21, R22)
			buffer.copy(b, offset, zBasis)
			offset += 12

			local position = _packF32(X, Y, Z)
			buffer.copy(b, offset, position)
			offset += 12
		end

		return buffer.tostring(b)
	end

	local ServiceVisibilitySerialize = function(wantVisible)
		local ExplorerServiceVisibilityService = game:GetService("ExplorerServiceVisibilityService")
		local stringEncoder = Attribute_Encoders["string"]
		local typeId = Attribute_Type_Ids["string"]

		local count = 0
		local buffer_size = 4
		local names = {}
		local formatted = {}

		for _, service in game:GetChildren() do
			if ExplorerServiceVisibilityService:GetServiceVisibility(service) == wantVisible then
				local name = service.ClassName
				local buf, size = stringEncoder(name)

				count += 1
				names[count] = name
				formatted[name] = buf

				buffer_size += 1 + size
			end
		end

		if count == 0 then
			return "\0\0\0\0"
		end

		table.sort(names)

		local b = buffer.create(buffer_size)
		buffer.writeu32(b, 0, count)

		local offset = 4
		for _, name in names do
			buffer.writeu8(b, offset, typeId)
			offset += 1

			local bb = formatted[name]
			buffer.copy(b, offset, bb)
			offset += buffer.len(bb)
		end

		return buffer.tostring(b)
	end

	local encodeTimeTicks = function(time)
		local scaled = time * 2400
		if not (scaled >= -2147483648 and scaled < 2147483648) then
			return -2147483648
		end
		return math.round(scaled)
	end

	local writeTimesSection = function(b, offset, keys)
		buffer.writeu32(b, offset, 1)
		offset += 4
		buffer.writeu32(b, offset, #keys)
		offset += 4
		for _, key in keys do
			buffer.writei32(b, offset, encodeTimeTicks(key.Time))
			offset += 4
		end
		return offset
	end

	local deriveTangentValueCurve = function(keys, i)
		local key = keys[i]
		local isFirst = (i == 1)
		local isLast = (i == #keys)
		if isLast then
			return 0, 0
		end
		if key.Interpolation == Enum.KeyInterpolationMode.Constant then
			return 0, 0
		end
		if key.Interpolation == Enum.KeyInterpolationMode.Linear then
			local nextKey = keys[i + 1]
			local t = 1 / (nextKey.Time - key.Time)
			return t, t
		end
		if isFirst then
			return 0, 0
		end
		local prevKey = keys[i - 1]
		local deltaPrev = key.Time - prevKey.Time
		if prevKey.Interpolation == Enum.KeyInterpolationMode.Constant then
			return 0, 0
		elseif prevKey.Interpolation == Enum.KeyInterpolationMode.Linear then
			local t = 1 / deltaPrev
			return t, t
		else
			local nextKey = keys[i + 1]
			local deltaNext = nextKey.Time - key.Time
			local t = (1 / deltaPrev + 1 / deltaNext) / 2
			return t, t
		end
	end

	local deriveTangentFloatCurve = function(keys, i)
		local key = keys[i]
		local isFirst = (i == 1)
		local isLast = (i == #keys)
		if isLast then
			return 0, 0
		end
		if key.Interpolation == Enum.KeyInterpolationMode.Constant then
			return 0, 0
		end
		if key.Interpolation == Enum.KeyInterpolationMode.Linear then
			local nextKey = keys[i + 1]
			local slope = (nextKey.Value - key.Value) / (nextKey.Time - key.Time)
			return slope, slope
		end
		if isFirst then
			return 0, 0
		end
		local prevKey = keys[i - 1]
		if prevKey.Interpolation == Enum.KeyInterpolationMode.Constant then
			return 0, 0
		elseif prevKey.Interpolation == Enum.KeyInterpolationMode.Linear then
			local slope = (key.Value - prevKey.Value) / (key.Time - prevKey.Time)
			return slope, slope
		else
			return 0, 0
		end
	end

	local encodeGuid = function(uid)
		local cleanGuid = string.gsub(uid, "[{}-]", "")
		local bytes = buffer.create(16)

		for i = 0, 15 do
			local hexByte = string.sub(cleanGuid, (i * 2) + 1, (i * 2) + 2)
			local val = tonumber(hexByte, 16) or 0
			buffer.writeu8(bytes, i, val)
		end

		return buffer.tostring(bytes)
	end

	local NotScriptableFixes = {
		Instance = {
			AttributesSerialize = function(instance)
				local attrs = instance:GetAttributes()

				if not next(attrs) then
					return ""
				end

				return AttributesSerialize(attrs)
			end,
			DefinesCapabilities = "Sandboxed",
			Tags = function(instance)
				local tags = CollectionService:GetTags(instance)

				if #tags == 0 then
					return ""
				end

				return table.concat(tags, "\0")
			end,

		},
		Path2D = {
			PropertiesSerialize = function(instance)
				local control_points = instance:GetControlPoints()
				local n = #control_points

				if n == 0 then
					return "\0\0\0\0"
				end

				local b = buffer.create(4 + n * 49)
				buffer.writeu32(b, 0, n)

				local typeId = Attribute_Type_Ids["Path2DControlPoint"]
				local encoder = Attribute_Encoders["Path2DControlPoint"]

				local offset = 4
				for i, point in control_points do
					local buf, bufSize = encoder(point)

					buffer.writeu8(b, offset, typeId)
					offset += 1

					buffer.copy(b, offset, buf)
					offset += bufSize
				end

				return buffer.tostring(b)
			end,
		},

		PlayerEmulatorService = {
			SerializedEmulatedPolicyInfo = function(instance)
				local EmulatedPolicyInfo = instance:GetEmulatedPolicyInfo()

				if not next(EmulatedPolicyInfo) then
					return ""
				end

				return AttributesSerialize(EmulatedPolicyInfo)
			end,
		},
		StyleRule = {
			PropertiesSerialize = function(instance)
				local props = instance:GetProperties()

				if not next(props) then
					return "\0\0\0\0"
				end

				return AttributesSerialize(props)
			end,
			PropertyTransitionsSerialize = function(instance)
				local transitions = instance:GetPropertyTransitions()

				if not next(transitions) then
					return "\2\0\0\0\0\0"
				end

				return AttributesSerialize(transitions, { 0x02, 0x00 })
			end,
		},
		StyleQuery = {
			ConditionsSerialize = function(instance)
				local props = instance:GetConditions()

				if not next(props) then
					return "\0\0\0\0"
				end

				return AttributesSerialize(props)
			end,
		},
		FloatCurve = {
			ValuesAndTimes = function(instance)

				local keys = instance:GetKeys()

				if #keys == 0 then
					return "\2\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0"
				end

				local valuesPayloadSize = #keys * 14
				local b = buffer.create(8 + valuesPayloadSize + 8 + (#keys * 4))

				buffer.writeu32(b, 0, 2)
				buffer.writeu32(b, 4, #keys)

				local offset = 8
				for i, key in keys do
					local lt, rt = key.LeftTangent, key.RightTangent
					local mode = countBits(lt, rt)

					if mode == 0 then
						lt, rt = deriveTangentFloatCurve(keys, i)
					elseif mode == 1 then
						rt = lt
					elseif mode == 2 then
						lt = rt
					end

					buffer.writeu8(b, offset, key.Interpolation.Value)
					offset += 1
					buffer.writeu8(b, offset, mode)
					offset += 1
					buffer.writef32(b, offset, key.Value)
					offset += 4
					buffer.writef32(b, offset, lt)
					offset += 4
					buffer.writef32(b, offset, rt)
					offset += 4
				end

				offset = writeTimesSection(b, offset, keys)

				return buffer.tostring(b)
			end,
		},
		RotationCurve = {
			ValuesAndTimes = function(instance)
				local keys = instance:GetKeys()

				if #keys == 0 then
					return "\1\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0"
				end

				local perKeySize = 25
				local b = buffer.create(8 + (#keys * perKeySize) + 8 + (#keys * 4))

				buffer.writeu32(b, 0, 1)
				buffer.writeu32(b, 4, #keys)

				local offset = 8
				for _, key in keys do
					local lt = key.LeftTangent or 0
					local rt = key.RightTangent or 0
					local qx, qy, qz, qw = cframeToQuaternion(key.Value)

					buffer.writeu8(b, offset, 12 + key.Interpolation.Value)
					offset += 1
					buffer.writef32(b, offset, qx)
					offset += 4
					buffer.writef32(b, offset, qy)
					offset += 4
					buffer.writef32(b, offset, qz)
					offset += 4
					buffer.writef32(b, offset, qw)
					offset += 4
					buffer.writef32(b, offset, lt)
					offset += 4
					buffer.writef32(b, offset, rt)
					offset += 4
				end

				offset = writeTimesSection(b, offset, keys)

				return buffer.tostring(b)
			end,
		},
		ValueCurve = {
			ValuesAndTimes = function(instance)
				local keys = instance:GetKeys()

				if #keys == 0 then
					return "\2\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0"
				end

				local valueTypeName = instance.ValueType

				local typeId = Attribute_Type_Ids[valueTypeName]

				if not typeId then
					valueTypeName = resolveTypeName(keys[1].Value)

					typeId = Attribute_Type_Ids[valueTypeName]
				end

				local encoder = Attribute_Encoders[valueTypeName]

				if not encoder then
					return "\2\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0"
				end

				local n = #keys
				local bufs = table.create(n)
				local sizes = table.create(n)
				local valuesPayloadSize = 0

				for i, key in keys do
					local dataBuf, dataSize = encoder(key.Value)
					bufs[i] = dataBuf
					sizes[i] = dataSize
					valuesPayloadSize += 15 + dataSize
				end

				local b = buffer.create(8 + valuesPayloadSize + 8 + 4 * n)
				buffer.writeu32(b, 0, 2)
				buffer.writeu32(b, 4, n)

				local offset = 8
				for i, key in keys do
					local lt, rt = key.LeftTangent, key.RightTangent
					local dataSize = sizes[i]

					buffer.writeu8(b, offset, key.Interpolation.Value)
					offset += 1
					buffer.writeu8(b, offset, countBits(lt, rt))
					offset += 1
					buffer.writeu32(b, offset, dataSize + 1)
					offset += 4
					buffer.writeu8(b, offset, typeId)
					offset += 1
					buffer.copy(b, offset, bufs[i])
					offset += dataSize

					if lt == nil and rt == nil then
						lt, rt = deriveTangentValueCurve(keys, i)
					elseif lt == nil then
						lt = rt
					elseif rt == nil then
						rt = lt
					end

					buffer.writef32(b, offset, lt)
					offset += 4
					buffer.writef32(b, offset, rt)
					offset += 4
				end

				offset = writeTimesSection(b, offset, keys)

				return buffer.tostring(b)
			end,
		},
		MarkerCurve = {
			ValuesAndTimes = function(instance)
				local markers = instance:GetMarkers()
				local n = #markers

				if n == 0 then
					return "\2\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0"
				end

				local strings_size = 0
				for _, marker in markers do
					strings_size += #marker.Value + 1
				end

				local b = buffer.create(8 + strings_size + 8 + (n * 4))

				buffer.writeu32(b, 0, 2)
				buffer.writeu32(b, 4, n)

				local offset = 8
				for _, marker in markers do
					local value = marker.Value
					buffer.writestring(b, offset, value)
					offset += #value + 1

				end

				offset = writeTimesSection(b, offset, markers)

				return buffer.tostring(b)
			end,
		},
		AnimationNodeDefinition = {
			InputPinData = function(instance)
				local input_pins = instance:GetOrderedInputPinNames()

				local n = #input_pins

				if n == 0 then
					return "\1\0\0\0\0\0\0\0"
				end

				local buffer_size = 8

				for _, pin in input_pins do
					buffer_size += 4 + #pin
				end

				local b = buffer.create(buffer_size)

				buffer.writeu32(b, 0, 1)
				buffer.writeu32(b, 4, n)

				local encoder = Attribute_Encoders["string"]
				local offset = 8
				for _, pin in input_pins do
					local pinBuf, pinSize = encoder(pin)

					buffer.copy(b, offset, pinBuf)
					offset += pinSize
				end

				return buffer.tostring(b)
			end,
		},
		AnimationClip = {
			GuidBinaryString = function(instance)
				return encodeGuid(instance.Guid)
			end,
		},
		AnimationRigData = {
			label = function(instance)
				local labels = instance:GetLabels()
				local n = #labels

				if n == 0 then
					return "\1\0\0\0\0\0\0\0"
				end

				local b = buffer.create(8 + n * 4)

				buffer.writeu32(b, 0, 1)
				buffer.writeu32(b, 4, n)

				local offset = 8

				for _, label in labels do
					buffer.writeu32(b, offset, label)
					offset += 4
				end

				return buffer.tostring(b)
			end,
			name = function(instance)
				local names = instance:GetNames()
				local n = #names

				if n == 0 then
					return "\1\0\0\0\0\0\0\0"
				end

				local buffer_size = 8

				for _, name in names do
					buffer_size += 4 + #name
				end

				local b = buffer.create(buffer_size)

				buffer.writeu32(b, 0, 1)
				buffer.writeu32(b, 4, n)

				local offset = 8

				for _, name in names do
					buffer.writeu32(b, offset, #name)
					offset += 4
				end
				for _, name in names do
					buffer.writestring(b, offset, name)
					offset += #name
				end

				return buffer.tostring(b)
			end,
			parent = function(instance)
				local parents = instance:GetParents()
				local n = #parents

				if n == 0 then
					return "\1\0\0\0\0\0\0\0"
				end

				local b = buffer.create(8 + #parents * 2)

				buffer.writeu32(b, 0, 1)
				buffer.writeu32(b, 4, n)

				local offset = 8

				for _, parent in parents do
					buffer.writeu16(b, offset, parent)
					offset += 2
				end

				return buffer.tostring(b)
			end,
			postTransform = function(instance)
				return TransformsSerialize(instance:GetPostTransforms())
			end,
			preTransform = function(instance)
				return TransformsSerialize(instance:GetPreTransforms())
			end,
			transform = function(instance)
				return TransformsSerialize(instance:GetTransforms())
			end,
		},
		AudioDeviceInput = {
			AccessList = function(instance)
				local userid_accesslist = instance:GetUserIdAccessList()

				local n = #userid_accesslist

				if n == 0 then
					return ""
				end

				local b = buffer.create(n * 8)

				local _writeI64LE = Attribute_Encoders._writeI64LE

				local offset = 0
				for _, user_id in userid_accesslist do
					_writeI64LE(b, offset, user_id)
					offset += 8
				end

				return buffer.tostring(b)
			end,
		},
		AudioEmitter = {
			AngleAttenuation = function(instance)
				return AttenuationSerialize(instance:GetAngleAttenuation())
			end,
			DistanceAttenuation = function(instance)
				return AttenuationSerialize(instance:GetDistanceAttenuation())
			end,
		},
		AudioListener = {
			AngleAttenuation = function(instance)
				return AttenuationSerialize(instance:GetAngleAttenuation())
			end,
			DistanceAttenuation = function(instance)
				return AttenuationSerialize(instance:GetDistanceAttenuation())
			end,
		},

		DebuggerBreakpoint = { line = "Line" },
		BallSocketConstraint = { MaxFrictionTorqueXml = "MaxFrictionTorque" },
		BasePart = {
			Color3uint8 = "Color",
			MaterialVariantSerialized = "MaterialVariant",
			size = "Size",
			siz = "Size",
		},
		DoubleConstrainedValue = { value = "Value" },
		IntConstrainedValue = { value = "Value" },

		CustomEvent = {
			PersistedCurrentValue = function(instance)
				local receiver = instance:GetAttachedReceivers()[1]
				if receiver then
					return receiver:GetCurrentValue()
				end

				local tempReceiver = Instance.new("CustomEventReceiver")
				local clone = Instance.fromExisting(instance)

				tempReceiver.Source = clone
				local value = tempReceiver:GetCurrentValue()

				tempReceiver:Destroy()
				clone:Destroy()

				return value
			end,
		},
		GuiObject = { Sink = "InputSink" },

		Terrain = {
			AcquisitionMethod = "LastUsedModificationMethod",

			MaterialColors = function(instance)

				local TERRAIN_MATERIAL_COLORS =
					{
						Enum.Material.Grass,
						Enum.Material.Slate,
						Enum.Material.Concrete,
						Enum.Material.Brick,
						Enum.Material.Sand,
						Enum.Material.WoodPlanks,
						Enum.Material.Rock,
						Enum.Material.Glacier,
						Enum.Material.Snow,
						Enum.Material.Sandstone,
						Enum.Material.Mud,
						Enum.Material.Basalt,
						Enum.Material.Ground,
						Enum.Material.CrackedLava,
						Enum.Material.Asphalt,
						Enum.Material.Cobblestone,
						Enum.Material.Ice,
						Enum.Material.LeafyGrass,
						Enum.Material.Salt,
						Enum.Material.Limestone,
						Enum.Material.Pavement,
					}

				local b = buffer.create(69)
				local offset = 6

				for _, material in TERRAIN_MATERIAL_COLORS do
					local color = instance:GetMaterialColor(material)
					buffer.writeu8(b, offset, (color.R * 255))
					offset += 1
					buffer.writeu8(b, offset, (color.G * 255))
					offset += 1
					buffer.writeu8(b, offset, (color.B * 255))
					offset += 1
				end

				return buffer.tostring(b)
			end,
		},
		BaseWrap = {
			TemporaryCageMeshContent = function(instance)
				return Content.fromUri(gethiddenproperty_fallback(instance, "TemporaryCageMeshId"))
			end,
		},
		MaterialVariant = {
			TexturePackContent = function(instance)
				return Content.fromUri(gethiddenproperty_fallback(instance, "TexturePack"))
			end,
		},
		TerrainDetail = {
			TexturePackContent = function(instance)
				return Content.fromUri(gethiddenproperty_fallback(instance, "TexturePack"))
			end,
		},
		WrapLayer = {
			TemporaryReferenceMeshContent = function(instance)
				return Content.fromUri(gethiddenproperty_fallback(instance, "TemporaryReferenceId"))
			end,
		},
		TriangleMeshPart = {
			FluidFidelityInternal = "FluidFidelity",
			PhysicalConfigData = function(instance)
				local blob = PHYSICAL_CONFIG_BY_CF[instance.CollisionFidelity]
				if blob == nil then
					blob = PHYSICAL_CONFIG_BY_CF[CF.Default]
				end
				return blob
			end,
		},
		MeshPart = {
			InitialSize = "MeshSize",
			MeshID = "MeshId",

		},
		PartOperation = {
			Content = function(instance)
				return Content.fromUri(gethiddenproperty_fallback(instance, "AssetId"))
			end,
			InitialSize = "MeshSize",
		},
		Part = { shape = "Shape", shap = "Shape" },
		TrussPart = { style = "Style" },
		FormFactorPart = {
			formFactorRaw = "FormFactor",
		},
		Fire = { heat_xml = "Heat", size_xml = "Size" },
		Clothing = {
			Outfit1Content = function(instance)
				return Content.fromUri(gethiddenproperty_fallback(instance, "Outfit1"))
			end,
			Outfit2Content = function(instance)
				return Content.fromUri(gethiddenproperty_fallback(instance, "Outfit2"))
			end,
		},
		Humanoid = {
			Health_XML = "Health",
			InternalBodyScale = function(instance)

				local a = instance.RootPart

				if not a then
					return __BREAK
				end

				return instance:GetAccessoryHandleScale(a, Enum.BodyPartR15.RootPart)
			end,
			InternalHeadScale = function(instance)

				local a = instance.Parent and instance.Parent:FindFirstChild("Head")

				if not a then
					return __BREAK
				end

				return instance:GetAccessoryHandleScale(a, Enum.BodyPartR15.Head).X
			end,
			NetworkHumanoidState = function(instance)
				return instance:GetState()
			end,
		},
		HumanoidDescription = {
			AccessoryBlob = function(instance)
				local blob = {}

				for _, acc in instance:GetAccessories(false) do
					table.insert(blob, {
						AssetId = acc.AssetId,
						Order = acc.Order,
						AccessoryType = acc.AccessoryType.Name,
						Puffiness = acc.Puffiness,
					})
				end

				return HttpService:JSONEncode(blob)
			end,
			EmotesDataInternal = function(instance)
				local emotes_data = ""
				for name, ids in instance:GetEmotes() do
					emotes_data ..= name .. "^" .. table.concat(ids, "^") .. "^\\"
				end
				return emotes_data
			end,
			EquippedEmotesDataInternal = function(instance)
				local equipped_emotes = instance:GetEquippedEmotes()
				if #equipped_emotes == 0 then
					return ""
				end

				local equipped_emotes_data = ""
				for _, emote in equipped_emotes do
					equipped_emotes_data = equipped_emotes_data .. emote.Slot .. "^" .. emote.Name .. "\\"
				end
				return equipped_emotes_data
			end,
		},
		LocalizationTable = {
			Contents = function(instance)
				return instance:GetContents()
			end,
		},
		MaterialService = { Use2022MaterialsXml = "Use2022Materials" },
		VideoPlayer = {
			PlayingReplicating = "IsPlaying",
		},

		Model = {
			ModelMeshCFrame = function(instance)
				return instance:GetModelCFrame()
			end,
			ModelMeshSize = function(instance)
				return instance:GetExtentsSize()
			end,
			Scale = function(instance)
				return instance:GetScale()
			end,
			ScaleFactor = function(instance)
				return instance:GetScale()
			end,
			WorldPivotData = "WorldPivot",
		},
		PackageLink = {
			PackageContentSerialize = "PackageContent",
			PackageIdSerialize = "PackageId",
			VersionIdSerialize = "VersionNumber",
		},
		Players = { MaxPlayersInternal = "MaxPlayers", PreferredPlayersInternal = "PreferredPlayers" },

		StarterPlayer = {
			AvatarJointUpgrade_SerializedRollout = "AvatarJointUpgrade",

		},
		Smoke = { size_xml = "Size", opacity_xml = "Opacity", riseVelocity_xml = "RiseVelocity" },
		Sound = {
			xmlRead_MinDistance_3 = "RollOffMinDistance",
			xmlRead_MaxDistance_3 = "RollOffMaxDistance",
		},
		ViewportFrame = {
			CameraCFrame = function(instance)
				local CurrentCamera = instance.CurrentCamera

				return CurrentCamera and CurrentCamera.CFrame or CFrame.identity
			end,
			CameraFieldOfView = function(instance)
				local CurrentCamera = instance.CurrentCamera

				return math.rad(CurrentCamera and CurrentCamera.FieldOfView or 70)
			end,
		},
		WeldConstraint = {
			CFrame0 = function(instance)
				local Part0, Part1 = instance.Part0, instance.Part1

				return Part0 and Part1 and Part0.CFrame:ToObjectSpace(Part1.CFrame) or CFrame.identity
			end,
			CFrame1 = function(instance)
				local Part0, Part1 = instance.Part0, instance.Part1

				return Part0 and Part1 and Part1.CFrame:ToObjectSpace(Part0.CFrame) or CFrame.identity
			end,
			Part0Internal = "Part0",
			Part1Internal = "Part1",
			State = function(instance)
				return countBits(instance.Enabled, instance.Active)
			end,
		},
		Workspace = {

			CollisionGroups = function(instance)
				local collision_groups = game:GetService("PhysicsService"):GetRegisteredCollisionGroups()

				local n = #collision_groups
				if n == 0 then
					return ""
				end

				local t = table.create(n)
				for i, group in collision_groups do
					t[i] = group.name .. "^" .. i - 1 .. "^" .. group.mask
				end
				return table.concat(t, "\\")
			end,
		},
		WorldRoot = {
			CollisionGroupData = function(instance)
				local collision_groups = game:GetService("PhysicsService"):GetRegisteredCollisionGroups()

				local n = #collision_groups

				if n == 0 then
					return "\1\0"
				end

				local buffer_size = 2

				for _, group in collision_groups do
					buffer_size += 7 + #group.name
				end

				local b = buffer.create(buffer_size)

				buffer.writeu8(b, 0, 1)
				buffer.writeu8(b, 1, n)

				local typeId_int32 = Attribute_Type_Ids["int32"]
				local offset = 2

				for i, group in collision_groups do
					local name, id, mask = group.name, i - 1, group.mask
					local name_len = #name

					buffer.writeu8(b, offset, id)
					offset += 1

					buffer.writeu8(b, offset, typeId_int32)
					offset += 1

					buffer.writei32(b, offset, mask)
					offset += 4

					buffer.writeu8(b, offset, name_len)
					offset += 1
					buffer.writestring(b, offset, name)
					offset += name_len
				end

				return buffer.tostring(b)
			end,
		},

		ServiceVisibilityService = {
			HiddenServices = function()
				return ServiceVisibilitySerialize(false)
			end,
			VisibleServices = function()
				return ServiceVisibilitySerialize(true)
			end,
		},

	}
	for _, enum_item in Enum.Material:GetEnumItems() do
		NotScriptableFixes.MaterialService[enum_item.Name .. "Name"] = function(instance)
			return instance:GetBaseMaterialOverride(enum_item)
		end
	end

	FetchAPI = function()
		local FILE_NAME = USSI_FOLDER .. "API_DUMP.json"

		local API_Dump

		local APIDUMP_FETCHERS = {
			[1] = function()
				local res = readfile(FILE_NAME)
				if res and res ~= "" then
					return HttpService:JSONDecode(res)[FULL_VERSION]
				end
			end,
			[2] = function()
				local client_version_str = tostring(CLIENT_VERSION)
				local dump
				local matching_versions, matched, is_matched, exact_match = {}, {}
				local process_line = function(line, noinsert)
					local file_version, patch_commit, version_hash =
						string.match(line, '"%d+%.(%d+)%.([^"]+)": "(version%-[^"]+)')
					if file_version == client_version_str then
						is_matched = true
						if version_hash and not matched[version_hash] then
							matched[version_hash] = true
							if not noinsert then
								table.insert(matching_versions, version_hash)
							end
							if string.sub(FULL_VERSION, -#patch_commit) == patch_commit then
								return version_hash
							end
						end
					elseif is_matched then
						return false
					end
				end

				local isFullDump = function(classes)
					for _, class in classes do
						for _, member in class.Members do
							if member.MemberType == "Property" then
								return member.Default ~= nil
							end
						end
					end
					return false
				end

				local tryFetchDump = function(url)
					local ok, decoded = pcall(function()
						local raw = game:HttpGet(url, true)
						return HttpService:JSONDecode(raw)
					end)
					return ok and decoded.Classes or nil
				end

				local fetchFullApiDump = function(hash)

					local decoded = tryFetchDump("https://setup.rbxcdn.com/" .. hash .. "-Full-API-Dump.json")
					if decoded and isFullDump(decoded) then
						return decoded
					end

					decoded = tryFetchDump(
						"https://raw.githubusercontent.com/setup-rbxcdn/roblox-full-api-dumps/refs/heads/main/full-dumps/"
							.. hash
							.. "-Full-API-Dump.json"
					)
					if decoded and isFullDump(decoded) then
						return decoded
					end

					return nil
				end

				do
					local o, r = pcall(
						game.HttpGet,
						game,
						"https://raw.githubusercontent.com/setup-rbxcdn/setup-rbxcdn.github.io/refs/heads/main/version-history/Windows/Studio64.json",
						true
					)
					if o then
						local version_history = string.split(r, "\n")
						version_history[#version_history] = nil

						for i = #version_history, 2, -1 do
							local res = process_line(version_history[i])
							if res == false then
								break
							elseif res then
								exact_match = res
							end
						end
					end
				end
				do
					local fallback_channel = function(channel)
						local ok, res = pcall(function()
							return HttpService:JSONDecode(
								game:HttpGet(
									"https://clientsettingscdn.roblox.com/v2/client-version/WindowsStudio64"
										.. (channel and "/channel/" .. channel or ""),
									true
								)
							)
						end)
						if not ok then
							return
						end
						if res.version and res.clientVersionUpload then
							local line = '"' .. res.version .. '": "' .. res.clientVersionUpload
							return process_line(line, true)
						end
					end
					if not exact_match then
						exact_match = fallback_channel("zbeta") or fallback_channel()
					end
				end
				if exact_match then
					dump = fetchFullApiDump(exact_match)
				end
				if not dump then
					for _, version_hash in matching_versions do
						dump = fetchFullApiDump(version_hash)
						if dump then
							break
						end
					end
				end
				return dump
			end,
			[3] = function()
				local classes, classes_size = {}, 1

				local renames = {
					CoordinateFrame = "CFrame",
					Rect2D = "Rect",
					Vector3Int16 = "Vector3int16",
					Vector2Int16 = "Vector2int16",
					Region3Int16 = "Region3int16",
				}

				for _, api_class in ReflectionService:GetClasses(REFLECTION_FILTER) do
					local members, members_size = {}, 1
					local className = api_class.Name

					local class = {
						Name = className,
						Members = members,
						Superclass = api_class.Superclass or "<<<ROOT>>>",
					}
					local permits = api_class.Permits

					local tags = {}
					if api_class.Service then
						table.insert(tags, "Service")
					elseif permits and permits["GetService"] then
						table.insert(tags, "Service")
					elseif not permits or not permits["New"] then
						table.insert(tags, "NotCreatable")
					end

					if #tags ~= 0 then
						class.Tags = tags
					end

					local o, r = pcall(
						ReflectionService.GetPropertiesOfClass,
						ReflectionService,
						className,
						REFLECTION_FILTER
					)
					if o then
						for _, property in r do
							local propertyName = property.Name

							local valueType = property.Type
							local valueType_Name = valueType.EngineType

							local category = valueType.Category

							local member_tags = {}

							if not next(property.Permits) then
								table.insert(member_tags, "NotScriptable")
							end

							if valueType_Name == "Enum" then
								category, valueType_Name = "Enum", valueType.EnumType
							elseif valueType_Name == "RefType" then
								category, valueType_Name = "Class", valueType.InstanceType
							else
								valueType_Name = renames[valueType_Name] or valueType_Name
							end

							local member = {
								Name = propertyName,
								MemberType = "Property",
								ValueType = { Name = valueType_Name, Category = category },
								Serialization = { CanLoad = property.Serialized, CanSave = property.Serialized },

							}

							if #member_tags ~= 0 then
								member.Tags = member_tags
							end

							members[members_size] = member
							members_size += 1
						end

					end
					classes[classes_size] = class
					classes_size += 1
				end

				return classes
			end,
			[4] = function()

				return HttpService:JSONDecode(
					game:HttpGet(
						"https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Mini-API-Dump.json",
						true
					)
				).Classes
			end,
		}

		for i, fetcher in APIDUMP_FETCHERS do
			local o, r = pcall(fetcher)
			if o and r then
				API_Dump = r
				if i == 2 then
					if writefile then
						local ok, err =
							pcall(writefile, FILE_NAME, HttpService:JSONEncode({ [FULL_VERSION] = API_Dump }))
						if not ok then
							warn("[DEBUG] DUMP writefile error", err)
						end
					end
				end
				break
			elseif r ~= false and 2 < i then
				warn("[DEBUG] Failed to get", FULL_VERSION, "version API Dump, trying fallbacks..")
				warn("[DEBUG] Method number:", i, "Reason:", r)
			end
		end

		local classList = {}
		local tmp_classDict, tmp_classParents = {}, {}

		local ClassesWhitelist, ClassesBlacklist = ClassPropertyExceptions.Whitelist, ClassPropertyExceptions.Blacklist

		local API_Dump_Decoded = API_Dump

		for _, API_Class in API_Dump_Decoded do
			local ClassName = API_Class.Name
			local props = {}

			for _, Member in API_Class.Members do
				local MemberType = Member.MemberType
				if MemberType == "Property" or MemberType == "Function" then
					props[Member.Name] = {
						ValueType = MemberType == "Property" and Member.ValueType.Name,
						MemberType = MemberType,

					}
				end
			end

			tmp_classDict[ClassName] = props
			tmp_classParents[ClassName] = API_Class.Superclass
		end

		for _, API_Class in API_Dump_Decoded do
			local ClassProperties, ClassProperties_size = {}, 1
			local Class = {
				Properties = ClassProperties,
				Superclass = API_Class.Superclass,

				NotCreatable = nil,
			}

			local ClassName = API_Class.Name
			local ClassTags = API_Class.Tags

			if ClassTags then
				local Tags = arrayToDict(ClassTags, nil, nil, "string")

				Class.NotCreatable = Tags.NotCreatable
				Class.Service = Tags.Service
			end

			local NotScriptableFixClass = NotScriptableFixes[ClassName]

			local ClassWhitelist, ClassBlacklist = ClassesWhitelist[ClassName], ClassesBlacklist[ClassName]

			local ContentProperties
			for _, Member in API_Class.Members do
				if Member.MemberType == "Property" then
					local Serialization = Member.Serialization

					if Serialization.CanLoad then

						local PropertyName = Member.Name

						local ValueType = Member.ValueType
						local ValueType_Name = ValueType.Name

						if ValueType_Name == "Content" or ValueType_Name == "AssetContentMap" then

							if not ContentProperties then
								ContentProperties = {}

								local o, properties = pcall(
									ReflectionService.GetPropertiesOfClass,
									ReflectionService,
									ClassName,
									REFLECTION_FILTER
								)
								if o then
									for _, property in properties do
										ContentProperties[property.Name] = property.Serialized
									end
								end
							end
							if ContentProperties[PropertyName] ~= nil then
								Serialization.CanSave = ContentProperties[PropertyName]
							end
						end

						if
							(Serialization.CanSave or ClassWhitelist and ClassWhitelist[PropertyName])
							and not (ClassBlacklist and ClassBlacklist[PropertyName])
						then
							local MemberTags = Member.Tags

							local Special, PreferredDescriptorName

							if MemberTags then
								for _, tag in MemberTags do
									if type(tag) == "table" then
										PreferredDescriptorName = tag.PreferredDescriptorName
										if PreferredDescriptorName and Special then
											break
										end
									elseif tag == "NotScriptable" then
										Special = true
										if PreferredDescriptorName then
											break
										end
									end
								end
							end

							local preferredDescriptorProp
							if PreferredDescriptorName then
								preferredDescriptorProp = tmp_classDict[ClassName][PreferredDescriptorName]

								if
									preferredDescriptorProp == nil
									or (
										preferredDescriptorProp.MemberType == "Property"
										and ValueType_Name ~= preferredDescriptorProp.ValueType
									)
								then
									PreferredDescriptorName = nil
								end
							end

							local Property = {
								Name = PropertyName,
								Category = ValueType.Category,

								ValueType = ValueType_Name,

								Special = Special,

								CanRead = nil,
							}

							if string.sub(ValueType_Name, 1, 8) == "Optional" then

								Property.Optional = string.sub(ValueType_Name, 9)
							end

							local propNameNorm = string.lower(string.sub(PropertyName, 1, 1))
								.. string.sub(PropertyName, 2)
							local super = tmp_classParents[ClassName]
							while super do
								local superProps = tmp_classDict[super]
								if superProps then
									for parentName in superProps do
										if
											string.lower(string.sub(parentName, 1, 1)) .. string.sub(parentName, 2)
											== propNameNorm
										then
											Property.Shadows = true
											break
										end
									end
								end
								if Property.Shadows then
									break
								end
								super = tmp_classParents[super]
							end

							local NotScriptableFix = NotScriptableFixClass and NotScriptableFixClass[PropertyName]
							local accessFunc = PreferredDescriptorName
								and (
									preferredDescriptorProp.MemberType == "Property"
										and function(instance)
											return instance[PreferredDescriptorName]
										end
									or function(instance)
										return instance[PreferredDescriptorName](instance)
									end
								)

							Property.Fallback = NotScriptableFix
									and (type(NotScriptableFix) == "function" and NotScriptableFix or accessFunc and function(
										instance
									)
										local o, r = pcall(accessFunc, instance)
										if o then
											return r
										end
										return instance[NotScriptableFix]
									end or function(instance)
										return instance[NotScriptableFix]
									end)
								or accessFunc

							ClassProperties[ClassProperties_size] = Property
							ClassProperties_size += 1
						end
					end
				end
			end

			classList[ClassName] = Class
		end

		return classList
	end
end

if not ClassList then
	local ok, result = pcall(FetchAPI)
	if ok and type(result) == "table" then
		ClassList = result
	else
		ClassList = {}
	end
end

return function(...)
	local totalsize = 0

	local IgnoreProperties = {}
	local IgnoreList = arrayToDict({ "CoreGui", "CorePackages", Packages = false }, true)
	local NotCreatableFixes = arrayToDict({
		"",
		"AdvancedDragger",
		"AnimationTrack",
		"Dragger",
		"Player",
		"PlayerGui",
		"PlayerMouse",
		"PlayerScripts",
		"ScreenshotHud",
		"StudioData",
		"TextChatMessage",
		"TextSource",
		"TouchTransmitter",
		"Translator",
		CloudLocalizationTable = "LocalizationTable",
		Platform = "Part",
		Status = "Model",
	}, true)

	local Object
	local ExtraInstances = {}
	local IsModel = false

	local args = table.pack(...)
	for i = 1, args.n do
		local arg = args[i]
		local Type = typeof(arg)

		if Type == "Instance" then
			Object = arg
			IsModel = true
		elseif Type == "table" then
			if typeof(arg[1]) == "Instance" then
				ExtraInstances = arg
				IsModel = true
			elseif arg.Object and typeof(arg.Object) == "Instance" then
				Object = arg.Object
				IsModel = true
			end
		end
	end

	local IgnoreNotArchivable = true
	local SaveNotCreatable = false
	local TreatUnionsAsParts = false
	local SharedBinaryStrings = false
	local __DEBUG_MODE = false

	local InstancesOverrides = {}
	local ClassSerializableCache = {}
	local ReflectionUsable
	local HasAutoRemaps
	
	local replaceClassName = function(instance, InstanceName, ClassName)
		local InstanceOverride = InstancesOverrides[instance]

		if InstanceOverride then
			return InstanceOverride
		end

		if InstanceName ~= ClassName then
			InstanceOverride = { Properties = { Name = "[" .. ClassName .. "] " .. InstanceName } }
			InstancesOverrides[instance] = InstanceOverride
		end

		return InstanceOverride
	end

	local isClassSerializable = function(className)
		local known = ClassSerializableCache[className]
		if known ~= nil then
			return known
		end

		local getSerialized = function(name)
			return pcall(function()
				return ReflectionService:GetClass(name, REFLECTION_FILTER).Serialized
			end)
		end

		local ok, serialized = getSerialized(className)
		serializable = not ok or serialized == true

		ClassSerializableCache[className] = serializable
		return serializable
	end

	local refIsInvalid = function(target, valueType)
		if not target then
			return false
		end
		local className = target.ClassName

		local fix = NotCreatableFixes[className] or nil
		if fix then
			if not SaveNotCreatableWillBeEnabled then
				return false
			end
		elseif not isClassSerializable(className) then

			fix = "Folder"
		end
		return fix ~= nil and (valueType ~= "Instance" and valueType ~= fix)
	end

	local nilIsValid = function(category, optional)
		return optional ~= nil or category == "Class"
	end

	local filterPropVal = function(result, property, category, optional)
		if result == nil then
			return not nilIsValid(category, optional)
		end
		if result == "can't get value" then
			return true
		end

		if type(result) ~= "string" or #result > 256 then
			return false
		end
		if category == "Enum" then
			return true
		end
		local needle = property.ErrNeedle
		if not needle then
			needle = "Unable to get property " .. property.Name
			property.ErrNeedle = needle
		end
		return string.find(result, needle, 1, true) ~= nil
	end
	
	local GHP_STATE_FILE = USSI_FOLDER .. "GHP_STATE.json"
	local GHPDatatypeState = {}
	local GHPPersisted = {}
	local GHPVersionKey
	local GHPShadowed = true

	do
		local execName, execVersion = "UNKNOWN", "0"
		if identify_executor then
			execName, execVersion = identify_executor()
			if not execVersion then
				execVersion = "0"
			end
		end

		GHPVersionKey = string.sub(string.gsub(string.gsub(string.gsub(`{execName}_{execVersion}_{FULL_VERSION}`, "[^%w _]", ""), " +", " "), " +$", ""), 1, 240)
		
		if readfile then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(readfile(GHP_STATE_FILE))
			end)
			if ok and decoded[GHPVersionKey] then
				GHPPersisted = decoded[GHPVersionKey]
			end
		end
	end

	local saveGHPState = function()
		if not writefile then
			return
		end
		pcall(writefile, GHP_STATE_FILE, HttpService:JSONEncode({ [GHPVersionKey] = GHPPersisted }))
	end

	local ghpDatatypeAllowed = function(valueType)
		local state = GHPDatatypeState[valueType]
		if state ~= nil then
			return state
		end

		local persisted = GHPPersisted[valueType]
		if persisted == "ok" then
			state = true
		elseif persisted == "failed" or persisted == "crashed" then
			state = false
		else
			GHPPersisted[valueType] = "crashed"
			saveGHPState()
			state = true
		end

		GHPDatatypeState[valueType] = state
		return state
	end

	local ghpDatatypeReport = function(valueType, ok)
		local wantState = ok and "ok" or "failed"
		if GHPPersisted[valueType] == wantState then
			return
		end
		GHPPersisted[valueType] = wantState
		GHPDatatypeState[valueType] = ok
		saveGHPState()
	end

	local readProperty = function(instance, property)
		local PropertyName, ValueType, CanRead, Special =
			property.Name, property.ValueType, property.CanRead, property.Special

		if
			InstancesOverrides[instance] == nil
			and CanRead == true
			and not Special
			and not (ValueType == "ProtectedString" and PropertyName == "Source")
		then
			return instance[PropertyName]
		end

		local raw = __BREAK

		local InstanceOverride = InstancesOverrides[instance]
		if InstanceOverride then
			local PropertiesOverride = InstanceOverride.Properties
			if PropertiesOverride then
				local PropertyOverride = PropertiesOverride[PropertyName]
				if PropertyOverride ~= nil then
					return PropertyOverride
				end
			end
		end

		if ValueType == "ProtectedString" and PropertyName == "Source" then
			return __BREAK
		end

		local Category, Optional = property.Category, property.Optional

		if CanRead ~= false then
			local GHPKey = (Category == "Enum" or Category == "Class") and Category or ValueType

			if Special then
				if property.Shadows and GHPShadowed then
					property.CanRead = false
				elseif gethiddenproperty and ghpDatatypeAllowed(GHPKey) then
					local ok, result = pcall(gethiddenproperty, instance, PropertyName)
					if ok then
						raw = result
					end

					local filtered = filterPropVal(raw, property, Category, Optional)
					local realFailure = filtered and not (result == nil and nilIsValid(Category, Optional))

					ghpDatatypeReport(GHPKey, ok and not realFailure)

					if filtered then
						if realFailure then
							if __DEBUG_MODE then
								__DEBUG_MODE("Filtered", PropertyName)
							end
							property.CanRead = false
						end
						raw = __BREAK
					end
				end
			elseif CanRead then
				raw = instance[PropertyName]
			else
				local ok, result = pcall(index, instance, PropertyName)
				if ok then
					raw = result
				elseif not (property.Shadows and GHPShadowed) and gethiddenproperty and ghpDatatypeAllowed(GHPKey) then
					ok, result = pcall(gethiddenproperty, instance, PropertyName)
					ghpDatatypeReport(GHPKey, ok and not filterPropVal(result, property, Category, Optional))
					if ok then
						raw = result
						property.Special = true
					end
				end

				property.CanRead = ok

				if not ok or filterPropVal(raw, property, Category, Optional) then
					raw = __BREAK
				end
			end

			if raw ~= __BREAK then
				return raw
			end
		end

		local GHPFFailed, Fallback = property.GHPFFailed, property.Fallback
		if GHPFFailed and not Fallback then
			return __BREAK
		end

		if not GHPFFailed then
			local ok, result
			if gethiddenproperty_fallback then
				ok, result = pcall(gethiddenproperty_fallback, instance, PropertyName)
			end
			if result == nil and not nilIsValid(Category, Optional) then
				ok = nil
			end
			if ok then
				return result
			end
			GHPFFailed = true
			property.GHPFFailed = true
		end

		if GHPFFailed and Fallback then
			local ok, result = pcall(Fallback, instance)
			if ok then
				return result
			end
			property.Fallback = nil
			if __DEBUG_MODE then
				__DEBUG_MODE("Fix Failed", PropertyName, result)
			end
		end

		return __BREAK
	end

	local GetInheritedProps = function(className)
		local cached = inheritedProperties[className]
		if cached then
			return cached
		end

		local prop_list = {}
		local layer = ClassList[className]
		while layer do
			local layer_props = layer.Properties
			table.move(layer_props, 1, #layer_props, #prop_list + 1, prop_list)

			layer = ClassList[layer.Superclass]
		end
		inheritedProperties[className] = prop_list
		return prop_list
	end

	local collect = function(roots)
		local ctx = {
			entries = {},
			classList = {},
			ordered = {},
			refs = {},
			instCount = 0,
			instTypeCount = 0,
		}

		local entries, classList = ctx.entries, ctx.classList
		local ordered, refs = ctx.ordered, ctx.refs

		local recur
		recur = function(instance, parent)
			if entries[instance] then
				return
			end

			local override = InstancesOverrides[instance]
			local tagOverride = override and override.__ClassName
			local virtual = override and override.__Virtual

			local class = virtual or instance.ClassName
			local name = virtual and override.Properties.Name or instance.Name
			local unknownTag, propClass, skipEntirely

			if not tagOverride then
				if IgnoreNotArchivable and not instance.Archivable then
					return
				end

				skipEntirely = IgnoreList[instance]
				if skipEntirely then
					return
				end

				local onIgnoredList = IgnoreList[class]
				if onIgnoredList == false then
					skipEntirely = false
				elseif onIgnoredList and (onIgnoredList == true or onIgnoredList[name]) then
					return
				end

				local fix = NotCreatableFixes[class]

				if fix then
					if not SaveNotCreatable then
						return
					end
					class, override = fix, replaceClassName(instance, name, class)
					if class == "Folder" then
						propClass = "Instance"
					end
				elseif TreatUnionsAsParts and instance:IsA("PartOperation") then
					class, override = "Part", replaceClassName(instance, name, class)
					propClass = "BasePart"
				elseif not isClassSerializable(class) then
					class, override, propClass = "Folder", replaceClassName(instance, name, class), "Instance"
					HasAutoRemaps = true
				elseif not ClassList[class] then
					if __DEBUG_MODE then
						__DEBUG_MODE("Class not Found", class)
					end
					unknownTag, class, propClass = class, "Folder", "Instance"
				end
			elseif tagOverride == "Folder" then
				propClass = "Instance"
			end

			local e = {
				tag = unknownTag or tagOverride or class,

				class = tagOverride or class,
				propClass = propClass or class,
				override = override,

				propsOnly = virtual ~= nil or (override and override.__Synthetic),
				virtual = virtual ~= nil,

				parent = parent,
			}
			entries[instance] = e

			refs[instance] = ctx.instCount
			ctx.instCount += 1

			local bucket = e.tag
			if e.propsOnly then
				bucket ..= "\0" .. e.propClass .. "\0propsOnly"
			elseif e.propClass ~= bucket then
				bucket ..= "\0" .. e.propClass
			end
			local list = classList[bucket]
			if not list then
				list = {}
				classList[bucket] = list
				ctx.instTypeCount += 1
			end
			list[#list + 1] = instance

			local kids
			if skipEntirely ~= false then
				local children = (override and override.__Children) or (not virtual and instance:GetChildren())

				kids = table.create(#children)
				for _, child in children do
					recur(child, instance, ldIgnore == true and true or nil)
					if entries[child] then
						kids[#kids + 1] = child
					end
				end
			end
			e.children = kids or {}
			ordered[#ordered + 1] = instance
		end

		local roots_kept = table.create(#roots)
		for _, root in roots do
			recur(root)
			if entries[root] then
				roots_kept[#roots_kept + 1] = root
			end
		end
		ctx.roots = roots_kept

		return ctx
	end

	local pendingExtras = {}

	local register_extra = function(name, instanceOrTable, saveProps, customClassName, source)
		customClassName = customClassName or "Folder"
		local properties = { Name = name, Source = source }
		local extra = { customClassName = customClassName, properties = properties }

		if instanceOrTable and saveProps and type(instanceOrTable) ~= "table" then
			local existing = InstancesOverrides[instanceOrTable]
			if existing then
				existing.__ClassName = customClassName
				existing.Properties = properties
			else
				InstancesOverrides[instanceOrTable] = {
					__ClassName = customClassName,
					Properties = properties,
				}
			end
			extra.roots = { instanceOrTable }
		else
			local children
			if instanceOrTable then
				children = type(instanceOrTable) == "table" and instanceOrTable or instanceOrTable:GetChildren()
			end
			local node = {}
			InstancesOverrides[node] = {
				__ClassName = customClassName,
				__Virtual = customClassName,
				__Children = children or {},
				Properties = properties,
			}
			extra.roots = { node }
		end

		pendingExtras[#pendingExtras + 1] = extra
		return extra
	end

	local emitBinary = function(ctx)
		local readAll = function(objs, prop, vals)
			local n = #objs

			for i = 1, n do
				local raw = readProperty(objs[i], prop)
				if raw == __BREAK then
					return nil, i
				end
				vals[i] = raw
			end

			return vals
		end

		local buildChunk = function(name, chunkBuf, compress)
			local uncompressedLen = chunkBuf.len
			local head = buffer.create(16)
			buffer.writestring(head, 0, name)

			if compress then
				local dataStr = compress(chunkBuf:tostring())
				if dataStr and #dataStr < uncompressedLen then
					buffer.writeu32(head, 4, #dataStr)
					buffer.writeu32(head, 8, uncompressedLen)
					return { buf = head, len = 16, str = dataStr }
				end
			end

			buffer.writeu32(head, 8, uncompressedLen)

			return {
				buf = head,
				len = 16,
				tailBuf = chunkBuf.buf,
				tailLen = uncompressedLen,
			}
		end

		local compress = function(raw)
			return zstdcompress(raw, 9)
		end

		local entries, classList = ctx.entries, ctx.classList
		local refs, ordered = ctx.refs, ctx.ordered
		local instCount, instTypeCount = ctx.instCount, ctx.instTypeCount

		local chunks, propChunks = {}, {}

		local lastStatus = 0

		local emit = function(chunk)
			chunks[#chunks + 1] = chunk
			totalsize += chunk.len + (chunk.str and #chunk.str or chunk.tailLen or 0)
		end

		do
			local header = buffer.create(32)
			buffer.writestring(header, 0, "\60\114\111\98\108\111\120\33\137\255\13\10\26\10\0\0")
			buffer.writei32(header, 16, instTypeCount)
			buffer.writei32(header, 20, instCount)
			emit({ buf = header, len = 32 })
		end

		if IsModel then
			local metaBuf = StreamBuffer.new(64)
			metaBuf:writeu32(1)
			metaBuf:writeLenString("ExplicitAutoJoints")
			metaBuf:writeLenString("true")
			emit(buildChunk("META", metaBuf, compress))
		end

		local sstrSlot = #chunks + 1

		local sharedStringCtx = { count = 0, order = {}, hashes = {} }

		local classId = 0
		local deferredBuckets
		local compiledProperties = {}

		local getCompiledProperties = function(className)
			local cached = compiledProperties[className]
			if cached then
				return cached
			end

			local source = GetInheritedProps(className)
			local result = table.create(#source)
			local count = 0

			for i = 1, #source do
				local prop = source[i]
				local propName = prop.Name

				if not IgnoreProperties[propName] then
					local valueType = prop.ValueType
					local binaryType = valueType
					local refMode = 0

					if prop.Category == "Enum" then
						binaryType = "Enum"
					elseif prop.Category == "Class" then
						binaryType = "Referent"
						refMode = 1
					elseif binaryType == "Content" then
						refMode = 1
					end

					if SharedBinaryStrings and binaryType == "BinaryString" then
						binaryType = "SharedString"
					end

					local typeId = Type_Ids[binaryType]
					local encoder = Binary_Encoders[binaryType]

					if typeId == Type_Ids.SharedString then
						refMode = 2
					end

					count += 1
					result[count] = {
						prop = prop,
						name = propName,
						valueType = valueType,
						binaryType = binaryType,
						typeId = typeId,
						encoder = encoder,
						refMode = refMode,
					}
				end
			end

			compiledProperties[className] = result
			return result
		end

		local encode_class_bucket = function(objs)
			local n = #objs
			local entry = entries[objs[1]]

			local class = entry.class

			local instBuf = StreamBuffer.new(64 + 4 * n)
			instBuf:writeu32(classId)
			instBuf:writeLenString(class)
			local classInfo = ClassList[class]

			local isService = classInfo and classInfo.Service
			instBuf:writeu8(isService and 1 or 0)
			instBuf:writeu32(n)

			writeRefPlane(instBuf, n, instBuf:allocRegion(4 * n), function(i)
				return refs[objs[i]]
			end)

			if isService then
				buffer.fill(instBuf.buf, instBuf:allocRegion(n), 1, n)
			end

			emit(buildChunk("INST", instBuf, compress))

			if entry.propsOnly then
				for propName in entry.override.Properties do
					local isSource = propName == "Source"
					local buf = StreamBuffer.new(64 + n * 16)
					buf:writeu32(classId)
					buf:writeLenString(propName)
					buf:writeu8(isSource and Type_Ids.ProtectedString or Type_Ids.string)

					for i = 1, n do
						local value = entries[objs[i]].override.Properties[propName]
						if type(value) == "function" then
							value = value()
						end
						buf:writeLenString(value or "")
					end

					local chunk = buildChunk("PROP", buf, not isSource and compress or nil)
					propChunks[#propChunks + 1] = chunk
					totalsize += chunk.len + (chunk.str and #chunk.str or chunk.tailLen or 0)
				end
			else
				local properties = getCompiledProperties(entry.propClass)
				local vals = table.create(n)

				for i = 1, #properties do
					local compiled = properties[i]
					local prop = compiled.prop
					local propName = compiled.name
					local valueType = compiled.valueType
					local binaryType = compiled.binaryType
					local encoder = compiled.encoder
					local typeId = compiled.typeId
					local refCtxArg = compiled.refMode == 1 and refs or compiled.refMode == 2 and sharedStringCtx or nil

					local readValues, failedAt = readAll(objs, prop, vals)
					if not readValues then
						if __DEBUG_MODE then
							__DEBUG_MODE("PROP dropped", class, propName, "n=" .. #objs, "failed at " .. failedAt)
						end
						continue
					end

					if encoder and typeId then
						if (SaveNotCreatableWillBeEnabled or HasAutoRemaps) and prop.Category == "Class" then
							for i = 1, n do
								if refIsInvalid(vals[i], valueType) then
									vals[i] = nil
								end
							end
						end

						local propBuf = StreamBuffer.new(128 + #objs * 4)
						propBuf:writeu32(classId)
						propBuf:writeLenString(propName)
						propBuf:writeu8(typeId)

						encoder(propBuf, vals, #objs, refCtxArg)
						local chunk = buildChunk("PROP", propBuf, compress)
						propChunks[#propChunks + 1] = chunk
						totalsize += chunk.len + (chunk.str and #chunk.str or chunk.tailLen or 0)
					else
						warn("UNSUPPORTED BINARY TYPE (OPEN A GITHUB ISSUE): ", propName, binaryType)
					end
				end
			end

			classId += 1
		end

		for _, objs in classList do
			if entries[objs[1]].deferLast then
				deferredBuckets = deferredBuckets or {}
				table.insert(deferredBuckets, objs)
			else
				encode_class_bucket(objs)
			end
		end

		if deferredBuckets then
			for _, objs in deferredBuckets do
				encode_class_bucket(objs)
			end
		end

		if sharedStringCtx.count > 0 then
			local sstrBuf = StreamBuffer.new(64 + sharedStringCtx.count * 32)
			sstrBuf:allocRegion(4)
			sstrBuf:writeu32(sharedStringCtx.count)
			for i = 1, sharedStringCtx.count do
				sstrBuf:allocRegion(16)
				sstrBuf:writeLenString(sharedStringCtx.order[i])
			end
			local chunk = buildChunk("SSTR", sstrBuf, compress)
			table.insert(chunks, sstrSlot, chunk)

			totalsize += chunk.len + (chunk.str and #chunk.str or chunk.tailLen or 0)
		end

		if #propChunks > 0 then
			table.move(propChunks, 1, #propChunks, #chunks + 1, chunks)
		end

		do
			local prntBuf = StreamBuffer.new(16 + instCount * 8)
			prntBuf:allocRegion(1)
			prntBuf:writeu32(instCount)

			local objBase = prntBuf:allocRegion(4 * instCount)
			local parBase = prntBuf:allocRegion(4 * instCount)

			writeRefPlane(prntBuf, instCount, objBase, function(i)
				return refs[ordered[i]]
			end)
			writeRefPlane(prntBuf, instCount, parBase, function(i)
				local par = entries[ordered[i]].parent
				return (par and refs[par]) or -1
			end)

			emit(buildChunk("PRNT", prntBuf, compress))
		end

		do
			local endBuf = StreamBuffer.new(16)
			endBuf:writestring("</roblox>")
			emit(buildChunk("END\0", endBuf, nil))
		end

		local out = table.create(#chunks)
		for i, c in chunks do
			local payloadLen = c.str and #c.str or c.tailLen or 0

			if payloadLen == 0 then
				out[i] = buffer.readstring(c.buf, 0, c.len)
			else
				local chunkBuf = buffer.create(c.len + payloadLen)
				buffer.copy(chunkBuf, 0, c.buf, 0, c.len)

				if c.str then
					buffer.writestring(chunkBuf, c.len, c.str)
				else
					buffer.copy(chunkBuf, c.len, c.tailBuf, 0, payloadLen)
				end

				out[i] = buffer.tostring(chunkBuf)
			end
		end

		return table.concat(out)
	end

	local ToSaveList

	if #ExtraInstances > 0 then
		ToSaveList = table.clone(ExtraInstances)
	else
		ToSaveList = {}
	end

	if Object then
		table.insert(ToSaveList, 1, Object)
	elseif #ToSaveList == 0 then
		for _, child in game:GetChildren() do
			ToSaveList[#ToSaveList + 1] = child
		end
	end

	local allRoots = table.clone(ToSaveList)
	for _, extra in pendingExtras do
		for _, root in extra.roots do
			allRoots[#allRoots + 1] = root
		end
	end

	local ctx = collect(allRoots)

	for _, extra in pendingExtras do
		local src = extra.roots
		local kept = table.create(#src)
		for _, root in src do
			if ctx.entries[root] then
				kept[#kept + 1] = root
			end
		end
		extra.collectedRoots = kept
	end

	local claimed = {}
	for _, extra in pendingExtras do
		for _, root in extra.collectedRoots do
			claimed[root] = true
			local rootEntry = ctx.entries[root]
			local isVirtual = rootEntry and rootEntry.virtual
			local toDetach = isVirtual and table.clone(rootEntry.children) or { root }

			for _, node in toDetach do
				local e = ctx.entries[node]
				local old = e.parent and ctx.entries[e.parent]

				if e.parent ~= root then
					if old then
						local kids = old.children
						for i = #kids, 1, -1 do
							if kids[i] == node then
								table.remove(kids, i)
								break
							end
						end
					end
					e.parent = isVirtual and root or nil
				end
			end
		end
	end

	local mainRoots = table.create(#ctx.roots)
	for _, root in ctx.roots do
		if not claimed[root] then
			mainRoots[#mainRoots + 1] = root
		end
	end
	ctx.mainRoots = mainRoots

	return emitBinary(ctx)
end
