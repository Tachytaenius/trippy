local normaliseOrZero = require("modules.normalise-or-zero")

local function moveVectorToTarget(current, target, rate, dt)
	local currentToTarget = target - current
	local direction = normaliseOrZero(currentToTarget)
	local distance = #currentToTarget
	local newCurrentToTarget = direction * math.max(0, distance - rate * dt)
	return target - newCurrentToTarget
end

return moveVectorToTarget
