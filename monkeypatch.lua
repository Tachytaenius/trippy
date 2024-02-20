local list = require("lib.list")
function list:elements() -- Convenient iterator
	local i = 1
	return function()
		local v = self:get(i)
		i = i + 1
		if v ~= nil then
			return v
		end
	end, self, 0
end
function list:find(obj) -- Same as list:has but without "and true"
	return self.pointers[obj]
end
