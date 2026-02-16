local damage = 100
local swingrate = 0.5
local anims={"GenericStab1","GenericStab2","StabPunch","Backstab"}
local lastAnim = ""
local ready = false
local equipped = false
local lastswing = 0

local storage = script.Parent:WaitForChild("Storage")
local down = storage:WaitForChild("MouseDown")
local debris = game:GetService("Debris")
local state = script.Parent:WaitForChild("SetState")
local throw = script.Parent:WaitForChild("RequestThrow")
local animEvent = script.Parent:WaitForChild("PlayAnimation")
local soundEvent = script.Parent:WaitForChild("PlayClientSound")
local serverScriptService = game:GetService("ServerScriptService")
local Hitboxes = require(serverScriptService.HitBoxes.HitboxCreator)

local player

while not player do
	if script.Parent.Parent:IsA("Model") then
		player = game.Players:GetPlayerFromCharacter(script.Parent.Parent)
	elseif script.Parent.Parent:IsA("Backpack") then
		player = script.Parent.Parent.Parent 
	end
	task.wait()
end


function runsound(id,volume)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://"..id
	sound.Volume = volume or 1
	sound.Parent = script.Parent.Handle
	debris:AddItem(sound,3)
	sound:Play()
end

function runAnimation(anim)
	animEvent:FireAllClients(anim)
end

function clientSound(ref)
	soundEvent:FireAllClients(ref)
end
local function triggerNearbyStabEvents(position, range)
	range = range or 9 
	for _, part in pairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and (part.Position - position).Magnitude <= range then
			local event = part:FindFirstChild("StabEvent")
			if event and event:IsA("BindableEvent") then
				event:Fire({Position = position})
			end
		end
	end
end

function ThrowAttack(player, targetPosition)

	if not player or not player.Character then return end
	if not script.Parent.Enabled then return end
	if script.Parent.Handle.Transparency == 1 then return end

	local character = player.Character
	local humanoid = character:FindFirstChild("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	local stateType = humanoid:GetState()
	if stateType == Enum.HumanoidStateType.Freefall
		or stateType == Enum.HumanoidStateType.Jumping
		or stateType == Enum.HumanoidStateType.Flying then
		return
	end

	script.Parent.Enabled = false
	local handle = script.Parent.Handle
	handle.Transparency = 1

	local startPosition = root.Position + root.CFrame.LookVector * 4
	local direction = (targetPosition - startPosition).Unit
	local speed = 50

	local knife = handle:Clone()
	knife.Name = "ThrownKnife"
	knife.Parent = workspace
	knife.CanCollide = false
	for s, h in pairs(knife:GetDescendants()) do
		if h:IsA("BasePart") then
			h.CanCollide = false
		end
	end
	knife.Massless = true
	knife.Transparency = 0
	knife.CFrame = CFrame.new(startPosition, startPosition + direction) * CFrame.Angles(0,0,math.rad(-90))

	local attachment = Instance.new("Attachment", knife)

	local linearVel = Instance.new("LinearVelocity")
	linearVel.Attachment0 = attachment
	linearVel.MaxForce = math.huge
	linearVel.VectorVelocity = direction * speed
	linearVel.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVel.Parent = knife

	local angularVel = Instance.new("AngularVelocity")
	angularVel.Attachment0 = attachment
	angularVel.MaxTorque = math.huge
	angularVel.AngularVelocity = Vector3.new(-speed,0,0)
	angularVel.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	angularVel.Parent = knife

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {character, knife}
	rayParams.IgnoreWater = true

	local lastPosition = knife.Position
	local hasHit = false
	local throwerId = player.UserId

	local function cleanup()
		if knife and knife.Parent then
			knife:Destroy()
		end
		if handle and handle.Parent then
			handle.Transparency = 0
			script.Parent.Enabled = true
		end
	end

	task.spawn(function()
		while knife.Parent and not hasHit do
			task.wait()

			local currentPosition = knife.Position
			local displacement = currentPosition - lastPosition

			if displacement.Magnitude > 0 then
				local result = workspace:Raycast(lastPosition, displacement, rayParams)

				if result then
					local hitPart = result.Instance
					local model = hitPart:FindFirstAncestorOfClass("Model")
					local hum = model and model:FindFirstChild("Humanoid")
					triggerNearbyStabEvents(result.Position, 5)

					if hum and hum.Health > 0 then
						local hitPlayer = game.Players:GetPlayerFromCharacter(model)
						if not hitPlayer or hitPlayer.UserId ~= throwerId then
							hasHit = true
							hum:TakeDamage(damage)
							clientSound("Critical")
						end

					elseif hitPart:IsA("BasePart") and hitPart.CanCollide then
						hasHit = true
						handle.WallHit:Play()
					end

					if hasHit then
						linearVel:Destroy()
						angularVel:Destroy()
						knife.Anchored = true
						knife.AssemblyLinearVelocity = Vector3.zero
						knife.AssemblyAngularVelocity = Vector3.zero
						knife.CanCollide = false

						task.wait(0.25)
						cleanup()
						break
					end
				end
			end

			lastPosition = currentPosition
		end
	end)

	task.delay(5, function()
		if not hasHit then
			cleanup()
		end
	end)
end

function Activate()
	if equipped and (tick()-lastswing)>=swingrate and ready and script.Parent.Enabled then
		script.Parent.Enabled = false
		runAnimation(anims[math.random(1,#anims)])
		lastswing = tick()

		local character = script.Parent.Parent
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then 
			script.Parent.Enabled = true
			return 
		end

		triggerNearbyStabEvents(root.Position, 5)
		
		Hitboxes.spawnHitbox(
			Vector3.new(4, 6, 5),
			character,
			nil,
			{character},
			10, 
			5,
			0.05, -- tick rate
			function(targetTable)
				local humanoid = targetTable.humanoid
				if humanoid and humanoid.Health > 0 then
					humanoid:TakeDamage(damage)
					clientSound("Normal")
					character.MurdererKills.Value += 1
				end
			end
		)

		task.wait(0.2)
		script.Parent.Enabled = true
	end
end

down.Changed:Connect(function()
	if down.Value then
		Activate()
	end
end)

script.Parent.Equipped:Connect(function()
	ready = true
	equipped = true
end)

script.Parent.Unequipped:Connect(function()
	down.Value = false
	ready = false
	equipped = false
end)

state.OnServerEvent:Connect(function(_,b)
	down.Value = b
end)

throw.OnServerEvent:Connect(ThrowAttack)
