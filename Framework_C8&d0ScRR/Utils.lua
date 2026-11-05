-- NXroENinD_DPcKage.Utils
-- Pure utility helpers. No external dependencies.

local Utils = {}

-- ── String ──────────────────────────────────────────────────────────────────

function Utils.trim(s)
    return s:match("^%s*(.-)%s*$")
end

function Utils.split(s, sep)
    sep = sep or "%s"
    local parts = {}
    for p in s:gmatch("([^" .. sep .. "]+)") do
        parts[#parts + 1] = p
    end
    return parts
end

function Utils.startsWith(s, prefix)
    return s:sub(1, #prefix) == prefix
end

function Utils.endsWith(s, suffix)
    return s:sub(-#suffix) == suffix
end

function Utils.format(fmt, ...)
    return string.format(fmt, ...)
end

-- ── Table ───────────────────────────────────────────────────────────────────

function Utils.keys(t)
    local k = {}
    for key in pairs(t) do k[#k + 1] = key end
    return k
end

function Utils.values(t)
    local v = {}
    for _, val in pairs(t) do v[#v + 1] = val end
    return v
end

function Utils.contains(t, val)
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

function Utils.filter(t, fn)
    local out = {}
    for _, v in ipairs(t) do
        if fn(v) then out[#out + 1] = v end
    end
    return out
end

function Utils.map(t, fn)
    local out = {}
    for i, v in ipairs(t) do out[i] = fn(v, i) end
    return out
end

function Utils.reduce(t, fn, init)
    local acc = init
    for _, v in ipairs(t) do acc = fn(acc, v) end
    return acc
end

function Utils.shallowCopy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- ── Math ────────────────────────────────────────────────────────────────────

function Utils.clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.round(n, places)
    places = places or 0
    local m = 10 ^ places
    return math.floor(n * m + 0.5) / m
end

function Utils.distance2D(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- ── Time ────────────────────────────────────────────────────────────────────

function Utils.timestamp()
    return os.time()
end

function Utils.clock()
    return os.clock()
end

-- ── Type checks ─────────────────────────────────────────────────────────────

function Utils.isVec3(v)
    return typeof(v) == "Vector3"
end

function Utils.isColor(v)
    return typeof(v) == "Color3"
end

-- ── Hex / binary ────────────────────────────────────────────────────────────

function Utils.toHex(n)
    return string.format("0x%04X", n)
end

function Utils.fromHex(s)
    return tonumber(s, 16)
end

-- ── Cooldown helper ─────────────────────────────────────────────────────────
-- Usage: local cd = Utils.Cooldown(1.0)  if cd() then ... end

function Utils.Cooldown(seconds)
    local last = -math.huge
    return function()
        local now = tick()
        if now - last >= seconds then
            last = now
            return true
        end
        return false
    end
end

return Utils
