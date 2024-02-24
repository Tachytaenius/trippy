local vec3 = require("lib.mathsies").vec3

local function normaliseOrZero(v)
	local zeroVector = vec3()
	return v == zeroVector and zeroVector or vec3.normalise(v)
end

return normaliseOrZero
