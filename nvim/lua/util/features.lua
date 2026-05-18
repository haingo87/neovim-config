local M = {}

local feature_map = {
	csharp = { implies = {} },
	unity  = { implies = { "csharp" } },
	cpp    = { implies = {} },
	cmake  = { implies = {} },
	go     = { implies = {} },
	dart   = { implies = {} },
	flutter= { implies = { "dart" } },
}

M.cache = {}

local function resolve_features(cfg)
	local features = cfg and cfg.features or {}
	local resolved = {}

	local function add(name)
		if resolved[name] then return end
		resolved[name] = true
		local entry = feature_map[name]
		if entry then
			for _, implied in ipairs(entry.implies) do
				add(implied)
			end
		end
	end

	for name, enabled in pairs(features) do
		if enabled then
			add(name)
		end
	end

	-- Backward compat: env.type → features
	if not next(resolved) and cfg and cfg.env and cfg.env.type then
		local t = cfg.env.type
		if t == "csharp" then
			resolved.csharp = true
		elseif t == "cpp" then
			resolved.cpp = true
		end
		vim.notify(
			"[features] .nvproj uses deprecated env.type='" .. t .. "'. Migrate to features = { " .. t .. " = true }",
			vim.log.levels.WARN
		)
	end

	return resolved
end

function M.load(parsed_cfg, nvproj_path)
	nvproj_path = nvproj_path or "default"
	if M.cache[nvproj_path] and not parsed_cfg then
		return M.cache[nvproj_path]
	end

	local resolved = resolve_features(parsed_cfg)

	-- Validation
	for name, _ in pairs(resolved) do
		if not feature_map[name] then
			vim.notify("[features] Unknown feature: " .. name, vim.log.levels.DEBUG)
		end
	end
	if resolved.csharp and resolved.cpp then
		vim.notify("[features] Both csharp and cpp enabled — C++/CLI?", vim.log.levels.DEBUG)
	end
	if resolved.cmake and not resolved.cpp then
		vim.notify("[features] cmake without cpp — standalone CMake?", vim.log.levels.DEBUG)
	end

	M.cache[nvproj_path] = resolved
	return resolved
end

function M.get_resolved()
	return M.cache[vim.g.project_nvproj_path or "default"]
end

function M.has(name)
	local resolved = M.get_resolved()
	return resolved and resolved[name] == true
end

function M.flush()
	M.cache = {}
end

return M
