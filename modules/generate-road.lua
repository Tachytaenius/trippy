local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat

local consts = require("consts")

-- TODO: Move to consts
local forwardVector = vec3(0, 0, 1)
local upVector = vec3(0, -1, 0)
local leftVector = vec3(-1, 0, 0)
local rightVector = vec3(1, 0, 0)

local tau = math.pi * 2

local function randomise(base, variationSize)
	return base + (love.math.random() - 0.5) * variationSize
end

local function randomInSphere(radius)
	local phi = love.math.random() * tau
	local cosTheta = love.math.random() * 2 - 1
	local u = love.math.random()

	local theta = math.acos(cosTheta)
	local r = radius * u ^ 1/3

	return r * vec3.fromAngles(theta, phi)
end

local function normaliseOrZero(v)
	local zeroVector = vec3()
	return v == zeroVector and zeroVector or vec3.normalise(v)
end

local function moveVectorToTarget(current, target, rate, dt)
	local currentToTarget = target - current
	local direction = normaliseOrZero(currentToTarget)
	local distance = #currentToTarget
	local newCurrentToTarget = direction * math.max(0, distance - rate * dt)
	return target - newCurrentToTarget
end

local function generateRoad(parameters)
	local path = {}
	local vertices = {}

	local newTargetAngularVelocityTimer = randomise(parameters.baseNewTargetAngularVelocityTimerLength, parameters.newTargetAngularVelocityTimerLengthVariationSize)
	local lengthTraversed = 0

	local currentPosition = vec3.clone(parameters.startPosition)
	local currentOrientation = quat.clone(parameters.startOrientation)
	local currentAngularVelocity = vec3.clone(parameters.startAngularVelocity)
	local targetAngularVelocity = vec3.clone(parameters.startAngularVelocity)

	while lengthTraversed < parameters.length do
		path[#path + 1] = {
			position = vec3.clone(currentPosition),
			orientation = quat.clone(currentOrientation),
			length = parameters.timeStep -- Time
		}

		-- Add to vertices
		local roadNormal = vec3.rotate(upVector, currentOrientation)
		local leftPos = currentPosition + vec3.rotate(leftVector * parameters.width / 2, currentOrientation)
		local rightPos = currentPosition + vec3.rotate(rightVector * parameters.width / 2, currentOrientation)
		local v = lengthTraversed / parameters.width / parameters.textureStretch
		vertices[#vertices + 1] = {
			leftPos.x, leftPos.y, leftPos.z,
			0, v,
			roadNormal.x, roadNormal.y, roadNormal.z
		}
		vertices[#vertices + 1] = {
			rightPos.x, rightPos.y, rightPos.z,
			1, v,
			roadNormal.x, roadNormal.y, roadNormal.z
		}
		-- Change twisting?
		newTargetAngularVelocityTimer = newTargetAngularVelocityTimer - parameters.timeStep
		if newTargetAngularVelocityTimer <= 0 then
			newTargetAngularVelocityTimer = randomise(parameters.baseNewTargetAngularVelocityTimerLength, parameters.newTargetAngularVelocityTimerLengthVariationSize)
			targetAngularVelocity = randomInSphere(parameters.maxNewTargetAngularSpeed)
		end
		-- Twist
		currentAngularVelocity = moveVectorToTarget(currentAngularVelocity, targetAngularVelocity, parameters.angularAcceleration, parameters.timeStep)
		currentOrientation = quat.normalise(currentOrientation * quat.fromAxisAngle(currentAngularVelocity * parameters.timeStep))
		-- Step forwards
		currentPosition = currentPosition + vec3.rotate(forwardVector, currentOrientation) * parameters.timeStep * parameters.lengthSpeed
		lengthTraversed = lengthTraversed + parameters.timeStep * parameters.lengthSpeed
	end

	return path, love.graphics.newMesh(consts.vertexFormat, vertices, "strip", "static")
end

return generateRoad
