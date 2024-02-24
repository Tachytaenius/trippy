local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat
local mat4 = mathsies.mat4

local consts = require("consts")

local normalMatrix = require("modules.normal-matrix")
local moveVectorToTarget = require("modules.move-vector-to-target")
local normaliseOrZero = require("modules.normalise-or-zero")

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

-- Mathsies does not have mat3 support
local function multiplyMat3WithVec3(mat3, v)
	return vec3(
		vec3.dot(v, vec3(mat3[1], mat3[2], mat3[3])),
		vec3.dot(v, vec3(mat3[4], mat3[5], mat3[6])),
		vec3.dot(v, vec3(mat3[8], mat3[7], mat3[9]))
	)
end

local function shallowClone(t)
	local ret = {}
	for k, v in pairs(t) do
		ret[k] = v
	end
	return ret
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

	local previousSliceVertices

	while lengthTraversed < parameters.length do
		path[#path + 1] = {
			position = vec3.clone(currentPosition),
			orientation = quat.clone(currentOrientation),
			length = parameters.timeStep -- Time
		}

		-- Add to vertices, or at least first slice1
		local v = lengthTraversed / parameters.width / parameters.textureStretch -- Texture coord v
		local thisSliceVertices = {} -- 0-based array
		if parameters.cylindrical then
			for i = 0, parameters.numVerticesPerSlice - 1 do
				local progress = i / parameters.numVerticesPerSlice
				local angle = progress * tau

				local posInSlice = vec3(
					math.cos(angle) * parameters.width / 2,
					math.sin(angle) * parameters.height / 2,
					0
				)
				local posInSpace = currentPosition + vec3.rotate(posInSlice, currentOrientation)

				local u = progress

				local normalInSlice = vec3.normalise(posInSlice)
				local sliceToSpace = mat4.transform(currentPosition, currentOrientation) -- Could use this to handle position as well
				local normalInSpace = multiplyMat3WithVec3({normalMatrix(sliceToSpace)}, normalInSlice)

				thisSliceVertices[i] = {
					posInSpace.x, posInSpace.y, posInSpace.z,
					u, v,
					normalInSpace.x, normalInSpace.y, normalInSpace.z
				}
			end
			if previousSliceVertices then
				for i = 0, parameters.numVerticesPerSlice - 1 do
					-- Form quads bridging slices with matching vertices
					-- Triangle 1
					vertices[#vertices + 1] = previousSliceVertices[i]
					vertices[#vertices + 1] = previousSliceVertices[(i + 1) % parameters.numVerticesPerSlice]
					vertices[#vertices + 1] = thisSliceVertices[i]
					-- Triangle 2
					vertices[#vertices + 1] = thisSliceVertices[i]
					vertices[#vertices + 1] = thisSliceVertices[(i + 1) % parameters.numVerticesPerSlice]
					vertices[#vertices + 1] = previousSliceVertices[(i + 1) % parameters.numVerticesPerSlice]
				end
				-- Handle final pair of triangles specially to avoid weird texture issues with the u coordinate
				-- We modify the vertices which were added using i + 1
				local function modify(amountToGoBack)
					local v = shallowClone(vertices[#vertices - amountToGoBack])
					v[4] = v[4] + 1
					vertices[#vertices - amountToGoBack] = v
				end
				modify(4)
				modify(1)
				modify(0)
			end
		else
			local function addVertex(posInSliceUnscaled, u)
				local posInSlice = vec3.clone(posInSliceUnscaled)
				posInSlice.x = posInSlice.x * parameters.width / 2
				posInSlice.y = posInSlice.y * parameters.height / 2
				local posInSpace = currentPosition + vec3.rotate(posInSlice, currentOrientation)
				thisSliceVertices[
					-- Get next empty position in 0-based array
					#thisSliceVertices + (thisSliceVertices[0] and 1 or 0)
				] = {
					posInSpace.x, posInSpace.y, posInSpace.z,
					u, v
					-- Must think on how to calculate normals here (TODO)
				}
			end
			-- Manually defining u values leads to some stretching... figure out solution
			-- Don't manually define any of this, probably.
			-- Top
			addVertex(vec3(-1, -0.1, 0), 0)
			addVertex(vec3(-0.9, 0, 0), 0.1)
			addVertex(vec3(0.9, 0, 0), 0.9)
			addVertex(vec3(1, -0.1, 0), 0.95)
			-- Bottom
			addVertex(vec3(1, -0.2, 0), 0)
			addVertex(vec3(0.9, -0.3, 0), 0.1)
			addVertex(vec3(-0.9, -0.3, 0), 0.9)
			addVertex(vec3(-1, -0.2, 0), 0.95)
			local finalVertexIndex = #thisSliceVertices + (thisSliceVertices[0] and 1 or 0) - 1
			if previousSliceVertices then
				for i = 0, finalVertexIndex do
					-- Form quads bridging slices with matching vertices
					-- Triangle 1
					vertices[#vertices + 1] = previousSliceVertices[i]
					vertices[#vertices + 1] = previousSliceVertices[(i + 1) % finalVertexIndex]
					vertices[#vertices + 1] = thisSliceVertices[i]
					-- Triangle 2
					vertices[#vertices + 1] = thisSliceVertices[i]
					vertices[#vertices + 1] = thisSliceVertices[(i + 1) % finalVertexIndex]
					vertices[#vertices + 1] = previousSliceVertices[(i + 1) % finalVertexIndex]
				end
			end
		end
		previousSliceVertices = thisSliceVertices
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

	return path, love.graphics.newMesh(consts.vertexFormat, vertices, "triangles", "static")
end

return generateRoad
