--!strict
--!optimize 2
--!native
--[[
	FreeCamera yay

	API:
		- FreeCam.ForwardDirection / FreeCam.RightDirection
		- FreeCam.CameraRotationX / FreeCam.CameraRotationY  (may be set directly)
		- FreeCam:GetRotationCFrame()  (cached, rebuilt only when the angles change)
		- FreeCam:ConsumeZoom()

	Touch:
		- Finger in the bottom-left region -> thumbstick (move)
		- Next finger -> look around
		- 2 non-thumbstick fingers -> pinch = zoom (move camera forward / back)
		- 3 non-thumbstick fingers -> pinch = FOV (spread = zoom in, close = zoom out)

	Trackpad:
		- Two-finger pan -> look around
		- Pinch -> zoom (move camera forward / back)
		- Shift + pinch -> FOV
]]

local vmagnitude = vector.magnitude
local sqrt = math.sqrt
local clamp = math.clamp
local min = math.min
local fromOrientation = CFrame.fromOrientation
local zero = vector.zero

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local KeyW = Enum.KeyCode.W
local KeyA = Enum.KeyCode.A
local KeyS = Enum.KeyCode.S
local KeyD = Enum.KeyCode.D
local KeyShift = Enum.KeyCode.LeftShift

local InputTypeMM = Enum.UserInputType.MouseMovement
local InputTypeMW = Enum.UserInputType.MouseWheel

local RAD_PER_PIXEL = -0.008726646259971648
local HALF_PI = 1.5707963267948966
local NEG_HALF_PI = -HALF_PI

local THUMBSTICK_DEADZONE_SQ = 0.05 * 0.05
local PINCH_SCALE = 0.2
local FOV_PINCH_SCALE = 0.2
local POINTER_PAN_SCALE = 1
local POINTER_PINCH_SCALE = 50

local FreeCamera = {}
FreeCamera.__index = FreeCamera

export type FreeCameraOptions = {
	ZoomSensitivity: number?,
	FOVSensitivity: number?,
	FOVMin: number?,
	FOVMax: number?,
}

function FreeCamera.new(options: FreeCameraOptions?)
	options = options or {}

	local self = setmetatable({}, FreeCamera)

	self._connections = {} :: {RBXScriptConnection}
	self._active = false

	self.Camera = Workspace.CurrentCamera :: Camera

	self.ZoomSensitivity = options.ZoomSensitivity or 2
	self.FOVSensitivity = options.FOVSensitivity or 2
	self.FOVMin = options.FOVMin or 5
	self.FOVMax = options.FOVMax or 120
	self.MouseCameraMove = true

	self.WPressed = false
	self.APressed = false
	self.SPressed = false
	self.DPressed = false
	self.ShiftPressed = false

	self.IsMoving = false
	self.ForwardDirection = 0
	self.RightDirection = 0

	local cframe = self.Camera and self.Camera.CFrame or CFrame.identity
	local rx, ry = cframe:ToEulerAnglesYXZ()
	self.CameraRotationX, self.CameraRotationY = rx, ry

	self._rotationCache = fromOrientation(rx, ry, 0)
	self._cacheX = rx
	self._cacheY = ry

	self.CameraMagnitude = 0

	self.ThumbstickEndX = 0
	self.ThumbstickStartY = 0
	self.ThumbstickSizeMultiplier = 60
	self._stickInvRadius = 1 / 60

	self.ThumbstickInputObject = nil :: InputObject?
	self.CameraRotateInputObject = nil :: InputObject?
	self.CameraZoomInputObject = nil :: InputObject?
	self.CameraFOVInputObject = nil :: InputObject?
	self.ThumbstickTouchStart = zero
	self._pinchDistance = 0
	self._fovSpread = 0

	self._customCondition = nil

	return self
end

function FreeCamera:_refreshKeyboardMovement()
	local forward = (self.WPressed and 1 or 0) - (self.SPressed and 1 or 0)
	local right = (self.DPressed and 1 or 0) - (self.APressed and 1 or 0)

	self.ForwardDirection = forward
	self.RightDirection = right
	self.IsMoving = forward ~= 0 or right ~= 0
end

function FreeCamera:_refreshTouchRegions()
	local ViewSizeX = Mouse.ViewSizeX
	local ViewSizeY = Mouse.ViewSizeY
	local Radius = min(ViewSizeX, ViewSizeY) <= 500 and 35 or 60

	ViewSizeY += GuiService.TopbarInset.Height

	self.ThumbstickEndX = ViewSizeX * 0.4
	self.ThumbstickStartY = ViewSizeY * 0.333
	self.ThumbstickSizeMultiplier = Radius
	self._stickInvRadius = 1 / Radius
end

function FreeCamera:_isBlocked(): boolean
	local condition = self._customCondition
	if condition and condition() == true then
		return true
	end
	return GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()
end

function FreeCamera:_applyFOVDelta(delta: number)
	local camera = self.Camera
	if camera then
		camera.FieldOfView = clamp(camera.FieldOfView - delta, self.FOVMin, self.FOVMax)
	end
end

function FreeCamera:_rotate(deltaX: number, deltaY: number)
	self.CameraRotationY += deltaX * RAD_PER_PIXEL
	self.CameraRotationX = clamp(self.CameraRotationX + deltaY * RAD_PER_PIXEL, NEG_HALF_PI, HALF_PI)
end

function FreeCamera:_fingerDistance(): number
	local a, b = self.CameraRotateInputObject, self.CameraZoomInputObject
	if not a or not b then return 0 end
	return vmagnitude(a.Position - b.Position)
end

function FreeCamera:_fingerSpread(): number
	local a, b, c = self.CameraRotateInputObject, self.CameraZoomInputObject, self.CameraFOVInputObject
	if not a or not b or not c then return 0 end
	local pa, pb, pc = a.Position, b.Position, c.Position
	local center = (pa + pb + pc) / 3
	return (vmagnitude(pa - center) + vmagnitude(pb - center) + vmagnitude(pc - center)) / 3
end

function FreeCamera:_rebaselinePinch()
	self._pinchDistance = self:_fingerDistance()
	self._fovSpread = self:_fingerSpread()
end

function FreeCamera:_resetTouchState()
	self.ThumbstickInputObject = nil
	self.CameraRotateInputObject = nil
	self.CameraZoomInputObject = nil
	self.CameraFOVInputObject = nil
	self.ThumbstickTouchStart = zero
	self._pinchDistance = 0
	self._fovSpread = 0
end

function FreeCamera:GetRotationCFrame(): CFrame
	local x, y = self.CameraRotationX, self.CameraRotationY
	if x ~= self._cacheX or y ~= self._cacheY then
		self._cacheX = x
		self._cacheY = y
		self._rotationCache = fromOrientation(x, y, 0)
	end
	return self._rotationCache
end

function FreeCamera:GetLookVector(): Vector3
	return self:GetRotationCFrame().LookVector
end

function FreeCamera:GetRightVector(): Vector3
	return self:GetRotationCFrame().RightVector
end

function FreeCamera:ConsumeZoom(): number
	local magnitude = self.CameraMagnitude
	self.CameraMagnitude = 0
	return magnitude
end

function FreeCamera:_bind()
	local conns = self._connections

	conns[#conns + 1] = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self.Camera = Workspace.CurrentCamera
	end)

	conns[#conns + 1] = UserInputService.InputBegan:Connect(function(input: InputObject)
		local keyCode = input.KeyCode
		if (keyCode ~= KeyW and keyCode ~= KeyA and keyCode ~= KeyS and keyCode ~= KeyD and keyCode ~= KeyShift) or self:_isBlocked() then
			return
		end

		if keyCode == KeyW then self.WPressed = true
		elseif keyCode == KeyA then self.APressed = true
		elseif keyCode == KeyS then self.SPressed = true
		elseif keyCode == KeyD then self.DPressed = true
		else self.ShiftPressed = true end

		self:_refreshKeyboardMovement()
	end)

	conns[#conns + 1] = UserInputService.InputEnded:Connect(function(input: InputObject)
		local keyCode = input.KeyCode

		if keyCode == KeyW then self.WPressed = false
		elseif keyCode == KeyA then self.APressed = false
		elseif keyCode == KeyS then self.SPressed = false
		elseif keyCode == KeyD then self.DPressed = false
		elseif keyCode == KeyShift then self.ShiftPressed = false
		else return end

		self:_refreshKeyboardMovement()
	end)

	conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input: InputObject, gp: boolean)
		if gp or self:_isBlocked() then return end
		local inputType = input.UserInputType

		if inputType == InputTypeMM then
			if not self.MouseCameraMove then return end
			local delta = input.Delta
			self:_rotate(delta.X, delta.Y)
		elseif inputType == InputTypeMW then
			local delta = input.Position.Z
			if self.ShiftPressed then
				self:_applyFOVDelta(delta * self.FOVSensitivity)
			else
				self.CameraMagnitude += delta * self.ZoomSensitivity
			end
		end
	end)

	conns[#conns + 1] = UserInputService.PointerAction:Connect(function(_wheel: number, pan: Vector2, pinch: number, gp: boolean)
		if gp or self:_isBlocked() then return end

		local panX, panY = pan.X, pan.Y
		if self.MouseCameraMove and (panX ~= 0 or panY ~= 0) then
			self:_rotate(panX * POINTER_PAN_SCALE, panY * POINTER_PAN_SCALE)
		end

		if pinch ~= 0 then
			if self.ShiftPressed then
				self:_applyFOVDelta(pinch * POINTER_PINCH_SCALE * self.FOVSensitivity)
			else
				self.CameraMagnitude += pinch * POINTER_PINCH_SCALE * self.ZoomSensitivity
			end
		end
	end)

	local onViewChanged = function()
		self:_refreshTouchRegions()
	end
	conns[#conns + 1] = Mouse:GetPropertyChangedSignal("ViewSizeX"):Connect(onViewChanged)
	conns[#conns + 1] = Mouse:GetPropertyChangedSignal("ViewSizeY"):Connect(onViewChanged)
	conns[#conns + 1] = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(onViewChanged)

	conns[#conns + 1] = UserInputService.TouchStarted:Connect(function(input: InputObject, gp: boolean)
		if gp or not self.MouseCameraMove or self:_isBlocked() then return end

		local position = input.Position

		if not self.ThumbstickInputObject and position.X <= self.ThumbstickEndX and position.Y >= self.ThumbstickStartY then
			self.ThumbstickInputObject = input
			self.ThumbstickTouchStart = position
		elseif not self.CameraRotateInputObject then
			self.CameraRotateInputObject = input
		elseif not self.CameraZoomInputObject then
			self.CameraZoomInputObject = input
			self:_rebaselinePinch()
		elseif not self.CameraFOVInputObject then
			self.CameraFOVInputObject = input
			self:_rebaselinePinch()
		end
	end)

	conns[#conns + 1] = UserInputService.TouchMoved:Connect(function(input: InputObject)
		if self:_isBlocked() then return end

		if input == self.ThumbstickInputObject then
			local position = input.Position
			local start = self.ThumbstickTouchStart
			local inv = self._stickInvRadius

			local x = (position.X - start.X) * inv
			local y = (start.Y - position.Y) * inv
			local sq = x * x + y * y

			if sq < THUMBSTICK_DEADZONE_SQ then
				self.RightDirection = 0
				self.ForwardDirection = 0
				self.IsMoving = false
				return
			end
			if sq > 1 then
				local scale = 1 / sqrt(sq)
				x *= scale
				y *= scale
			end

			self.RightDirection = x
			self.ForwardDirection = y
			self.IsMoving = true
			return
		end

		local rotateObject = self.CameraRotateInputObject
		local zoomObject = self.CameraZoomInputObject
		local fovObject = self.CameraFOVInputObject

		if fovObject and (input == rotateObject or input == zoomObject or input == fovObject) then
			local newSpread = self:_fingerSpread()
			self:_applyFOVDelta((newSpread - self._fovSpread) * FOV_PINCH_SCALE * self.FOVSensitivity)
			self._fovSpread = newSpread
		elseif zoomObject and (input == rotateObject or input == zoomObject) then
			local newDistance = self:_fingerDistance()
			self.CameraMagnitude += (newDistance - self._pinchDistance) * PINCH_SCALE * self.ZoomSensitivity
			self._pinchDistance = newDistance
		elseif input == rotateObject then
			local delta = input.Delta
			self:_rotate(delta.X, delta.Y)
		end
	end)

	conns[#conns + 1] = UserInputService.TouchEnded:Connect(function(input: InputObject)
		if input == self.ThumbstickInputObject then
			self.ThumbstickInputObject = nil
			self.ThumbstickTouchStart = zero

			self:_refreshKeyboardMovement()
			return
		end

		local rotateObject = self.CameraRotateInputObject
		local zoomObject = self.CameraZoomInputObject
		local fovObject = self.CameraFOVInputObject

		if input == rotateObject then
			self.CameraRotateInputObject = zoomObject
			self.CameraZoomInputObject = fovObject
			self.CameraFOVInputObject = nil
			self:_rebaselinePinch()
		elseif input == zoomObject then
			self.CameraZoomInputObject = fovObject
			self.CameraFOVInputObject = nil
			self:_rebaselinePinch()
		elseif input == fovObject then
			self.CameraFOVInputObject = nil
			self:_rebaselinePinch()
		end
	end)
end

function FreeCamera:_unbind()
	local conns = self._connections
	for i = 1, #conns do
		conns[i]:Disconnect()
	end
	table.clear(conns)
end

function FreeCamera:IsActive(): boolean
	return self._active
end

function FreeCamera:ConditionCheck(func: any)
	self._customCondition = if type(func) == "function" then func else nil
end

function FreeCamera:Start()
	if self._active then return end
	self._active = true

	self.Camera = Workspace.CurrentCamera
	self.CameraMagnitude = 0
	self:_resetTouchState()

	self.WPressed = UserInputService:IsKeyDown(KeyW)
	self.APressed = UserInputService:IsKeyDown(KeyA)
	self.SPressed = UserInputService:IsKeyDown(KeyS)
	self.DPressed = UserInputService:IsKeyDown(KeyD)
	self.ShiftPressed = UserInputService:IsKeyDown(KeyShift)
	self:_refreshKeyboardMovement()

	self:_refreshTouchRegions()
	self:_bind()
end

function FreeCamera:Stop()
	if not self._active then return end
	self._active = false
	self:_unbind()

	self:_resetTouchState()
	self.CameraMagnitude = 0
	self.IsMoving = false
	self.ForwardDirection = 0
	self.RightDirection = 0
end

function FreeCamera:Destroy()
	if self._active then
		self:Stop()
	end
	setmetatable(self :: any, nil)
end

return FreeCamera
