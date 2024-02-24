require("monkeypatch")

local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat
local mat4 = mathsies.mat4

local list = require("lib.list")

local consts = require("consts")

local generateRoad = require("modules.generate-road")
local normalMatrix = require("modules.normal-matrix")
local loadObj = require("modules.load-obj")
local moveVectorToTarget = require("modules.move-vector-to-target")

-- TODO: Move to consts
local upVector = vec3(0, -1, 0)

local tau = math.pi * 2

local meshShader, backgroundShader
local roadBaseTexture
local dummyTexture

local camera, objects
local currentPathStepIndex, currentPathStepTime
local time
local controllingCamera

local function lerp(a, b, i)
	return a + i * (b - a)
end

local function hsv2rgb(h, s, v)
	if s == 0 then
		return v, v, v
	end
	local _h = h / 60
	local i = math.floor(_h)
	local f = _h - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	elseif i == 5 then
		return v, p, q
	end
end

function love.load()
	love.graphics.setDepthMode("lequal", true)
	love.graphics.setFrontFaceWinding("ccw")

	camera = {
		position = vec3(0, -4, 0),
		velocity = vec3(),
		maxSpeed = 10,
		acceleration = 100,
		orientation = quat(),
		angularVelocity = vec3(),
		maxAngularSpeed = tau / 4,
		angularAcceleration = tau / 2,
		verticalFov = math.rad(90),
		nearPlaneDistance = 0.001,
		farPlaneDistance = 1000,
		speed = 100,
		angularSpeed = tau * 0.5
	}
	objects = list()
	local path, mesh = generateRoad({
		startPosition = vec3(0, 0, 0),
		startOrientation = quat(),
		startAngularVelocity = vec3(),
		timeStep = 0.25,
		lengthSpeed = 10,
		length = 10000,
		width = 20,
		height = 20,
		cylindrical = true,
		numVerticesPerSlice = 20,
		maxNewTargetAngularSpeed = 1,
		baseNewTargetAngularVelocityTimerLength = 12,
		newTargetAngularVelocityTimerLengthVariationSize = 2,
		angularAcceleration = 0.01,
		textureStretch = 4
	})
	objects:add({
		path = path,
		mesh = mesh,
		position = vec3(0, 0, 0),
		orientation = quat()
	})
	-- objects:add({
	-- 	mesh = loadObj("meshes/racer.obj"),
	-- 	position = vec3(0, 0, 0),
	-- 	orientation = quat()
	-- })

	currentPathStepIndex = 1
	currentPathStepTime = 0
	controllingCamera = false
	time = 0

	roadBaseTexture = love.graphics.newImage("textures/roadBase.png")
	roadBaseTexture:setWrap("repeat")
	dummyTexture = love.graphics.newImage(love.image.newImageData(1, 1))

	meshShader = love.graphics.newShader("shaders/mesh.glsl")
	backgroundShader = love.graphics.newShader("shaders/background.glsl")
end

function love.keypressed(key)
	if key == "space" then
		controllingCamera = true
	end
end

function love.update(dt)
	local path = objects:get(1).path
	local pathPosition, pathOrientation
	if currentPathStepIndex <= #path then
		local currentStep = path[currentPathStepIndex]
		local nextStep = path[currentPathStepIndex + 1] or currentStep
		local lerpFactor = currentPathStepTime / currentStep.length
		pathPosition = lerp(currentStep.position, nextStep.position, lerpFactor)
		pathOrientation = quat.slerp(currentStep.orientation, nextStep.orientation, lerpFactor)
		-- objects:get(2).position = pathPosition + vec3.rotate(upVector * 1, pathOrientation)
		-- objects:get(2).orientation = pathOrientation

		currentPathStepTime = currentPathStepTime + dt * 10
		if currentPathStepTime >= currentStep.length then
			currentPathStepIndex = currentPathStepIndex + 1
			currentPathStepTime = currentPathStepTime - currentStep.length
		end
	else
		controllingCamera = true
	end

	local targetVelocity, targetAngularVelocity = vec3(), vec3()
	if controllingCamera then
		local speed = love.keyboard.isDown("lshift") and 10 or 1
		local translation = vec3()
		if love.keyboard.isDown("w") then translation.z = translation.z + speed end
		if love.keyboard.isDown("s") then translation.z = translation.z - speed end
		if love.keyboard.isDown("a") then translation.x = translation.x - speed end
		if love.keyboard.isDown("d") then translation.x = translation.x + speed end
		if love.keyboard.isDown("q") then translation.y = translation.y + speed end
		if love.keyboard.isDown("e") then translation.y = translation.y - speed end
		targetVelocity = vec3.rotate(translation, camera.orientation) * camera.maxSpeed

		local angularSpeed = tau / 4
		local rotation = vec3()
		if love.keyboard.isDown("j") then rotation.y = rotation.y - angularSpeed end
		if love.keyboard.isDown("l") then rotation.y = rotation.y + angularSpeed end
		if love.keyboard.isDown("i") then rotation.x = rotation.x + angularSpeed end
		if love.keyboard.isDown("k") then rotation.x = rotation.x - angularSpeed end
		if love.keyboard.isDown("u") then rotation.z = rotation.z - angularSpeed end
		if love.keyboard.isDown("o") then rotation.z = rotation.z + angularSpeed end
		targetAngularVelocity = rotation * camera.maxAngularSpeed
	else
		camera.position = pathPosition + vec3.rotate(vec3(0, -2, -2), pathOrientation)
		camera.orientation = pathOrientation * quat.fromAxisAngle(vec3(-0.25, 0, 0))
	end
	camera.velocity = moveVectorToTarget(camera.velocity, targetVelocity, camera.acceleration, dt)
	camera.position = camera.position + camera.velocity * dt
	camera.angularVelocity = moveVectorToTarget(camera.angularVelocity, targetAngularVelocity, camera.angularAcceleration, dt)
	camera.orientation = quat.normalise(camera.orientation * quat.fromAxisAngle(camera.angularVelocity * dt))

	time = time + dt
end

function love.draw()
	local projectionMatrix = mat4.perspectiveLeftHanded(
		love.graphics.getWidth() / love.graphics.getHeight(),
		camera.verticalFov,
		camera.farPlaneDistance,
		camera.nearPlaneDistance
	)
	local cameraMatrixStationary = mat4.camera(vec3(), camera.orientation)

	backgroundShader:send("time", time)
	-- backgroundShader:send("viewQuaternion", {quat.components(camera.orientation)})
	backgroundShader:send("screenToSky", {mat4.components(
		mat4.inverse(projectionMatrix * cameraMatrixStationary)
	)})
	backgroundShader:send("nearPlaneDistance", camera.nearPlaneDistance)
	love.graphics.setDepthMode("lequal", false)
	love.graphics.setShader(backgroundShader)
	love.graphics.draw(dummyTexture, 0, 0, 0, love.graphics.getDimensions())

	love.graphics.setShader(meshShader)
	love.graphics.setDepthMode("lequal", true)
	-- love.graphics.setWireframe(true)
	meshShader:send("time", time)
	local cameraMatrix = mat4.camera(camera.position, camera.orientation)
	local first = true
	for object in objects:elements() do
		local baseTextureColour = {hsv2rgb((time * 30) % 360, 0.6, 2)}
		baseTextureColour[4] = 1
		local modelMatrix = mat4.transform(object.position, object.orientation)
		local modelToWorldMatrix = modelMatrix
		local modelToScreenMatrix = projectionMatrix * cameraMatrix * modelToWorldMatrix
		meshShader:send("baseTextureColour", baseTextureColour)
		meshShader:send("modelToWorld", {mat4.components(modelToWorldMatrix)})
		meshShader:send("modelToScreen", {mat4.components(modelToScreenMatrix)})
		meshShader:send("modelToWorldNormal", {normalMatrix(modelToWorldMatrix)})
		meshShader:send("baseTexture", roadBaseTexture)
		meshShader:send("drawTrippy", first)
		love.graphics.draw(object.mesh)
		first = false
	end
	love.graphics.setShader()
end
