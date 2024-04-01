local function readFile(path)
	local file = assert(io.open(path, "r"), "input file not found")
	local content = assert(file:read("*all"), "input file cannot be read")
	file:close()
	return content
end

local function writeFile(path, content)
	local file = assert(io.open(path, "w"), "output file cannot be open/created")
	assert(file:write(content), "output file cannot be written to")
	file:close()
end

local function extractFilename(path)
	local result = path:match(".+[\\/]([^\\/]+)$") or path
	return result
end

local function replaceContent(content, pattern, replacement)
	return content:gsub(pattern, replacement)
end

	--cli
assert(#{ ... } >= 4, "not enough arguments")
local pattern, replacement, inputPath, outputDir, v = ...

	--bez cli
--local pattern, replacement, inputPath, outputDir, v = "o+", "xx", "test.txt", "resources", v

local content = readFile(inputPath)
local newContent = replaceContent(content, pattern, replacement)
local outputPath = outputDir .. extractFilename(inputPath)
writeFile(outputPath, newContent)

if v then
	print("input:", inputPath)
	print("output:", outputPath)
	print("pattern:", pattern)
	print("replacement:", replacement)
end