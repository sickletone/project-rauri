--!nolint
-- Rauri :: web/js
-- A small JavaScript interpreter (an ES2017-ish subset) used by the web view.
-- It is intentionally not a full engine: expressions, functions, arrows,
-- control flow, arrays, objects, template strings and the host API cover the
-- kind of scripts UI developers write against the DOM.
--
-- The host API is injected by web/bindings.lua as a plain table of globals.

local Js = {}

local MAX_STEPS = 2000000

local KEYWORDS = {
	["let"] = true,
	["const"] = true,
	["var"] = true,
	["function"] = true,
	["return"] = true,
	["if"] = true,
	["else"] = true,
	["while"] = true,
	["for"] = true,
	["of"] = true,
	["in"] = true,
	["break"] = true,
	["continue"] = true,
	["true"] = true,
	["false"] = true,
	["null"] = true,
	["undefined"] = true,
	["typeof"] = true,
	["this"] = true,
	["new"] = true,
	["switch"] = true,
	["case"] = true,
	["default"] = true,
	["throw"] = true,
	["try"] = true,
	["catch"] = true,
	["finally"] = true,
	["class"] = true,
	["do"] = true,
	["delete"] = true,
}

-- Longest first.
local OPERATORS = {
	"===",
	"!==",
	"=>",
	"==",
	"!=",
	"<=",
	">=",
	"&&",
	"||",
	"++",
	"--",
	"+=",
	"-=",
	"*=",
	"/=",
	"...",
	"+",
	"-",
	"*",
	"/",
	"%",
	"=",
	"<",
	">",
	"!",
	"?",
	":",
	";",
	",",
	".",
	"(",
	")",
	"{",
	"}",
	"[",
	"]",
}

local ARRAY_MT = { __jsarray = true }

function Js.array(values)
	return setmetatable(values or {}, ARRAY_MT)
end

local function isArray(value)
	if type(value) ~= "table" then
		return false
	end
	local metatable = getmetatable(value)
	return metatable == ARRAY_MT or (type(metatable) == "table" and metatable.__jsarray == true)
end

local function tokenize(source)
	local tokens = {}
	local index = 1
	local length = #source
	local line = 1

	local function push(tokenType, value)
		tokens[#tokens + 1] = { type = tokenType, value = value, line = line }
	end

	local function alpha(ch)
		return ch ~= "" and ch:match("[%a_$]") ~= nil
	end

	local function alnum(ch)
		return ch ~= "" and ch:match("[%w_$]") ~= nil
	end

	local function digit(ch)
		return ch ~= "" and ch:match("%d") ~= nil
	end

	while index <= length do
		local ch = source:sub(index, index)
		if ch == "\n" then
			line += 1
			index += 1
		elseif ch:match("%s") then
			index += 1
		elseif ch == "/" and source:sub(index + 1, index + 1) == "/" then
			local newline = source:find("\n", index, true)
			index = newline and (newline + 1) or (length + 1)
		elseif ch == "/" and source:sub(index + 1, index + 1) == "*" then
			local close = source:find("*/", index + 2, true)
			local chunk = source:sub(index, close and close + 1 or length)
			for _ in chunk:gmatch("\n") do
				line += 1
			end
			index = close and (close + 2) or (length + 1)
		elseif ch == "'" or ch == '"' then
			local quote = ch
			local buffer = {}
			index += 1
			while index <= length do
				local current = source:sub(index, index)
				if current == "\\" then
					local escaped = source:sub(index + 1, index + 1)
					local map = {
						n = "\n",
						t = "\t",
						r = "\r",
						b = "\b",
						f = "\f",
						["\\"] = "\\",
						["'"] = "'",
						['"'] = '"',
					}
					if escaped == "u" then
						local code = tonumber(source:sub(index + 2, index + 5), 16)
						if code then
							local ok, decoded = pcall(utf8.char, code)
							buffer[#buffer + 1] = ok and decoded or "?"
						end
						index += 6
					elseif escaped == "x" then
						local code = tonumber(source:sub(index + 2, index + 3), 16)
						if code then
							local ok, decoded = pcall(utf8.char, code)
							buffer[#buffer + 1] = ok and decoded or "?"
						end
						index += 4
					else
						buffer[#buffer + 1] = map[escaped] or escaped
						index += 2
					end
				elseif current == quote then
					index += 1
					break
				else
					if current == "\n" then
						line += 1
					end
					buffer[#buffer + 1] = current
					index += 1
				end
			end
			push("string", table.concat(buffer))
		elseif ch == "`" then
			local startLine = line
			local buffer = {}
			index += 1
			while index <= length do
				local current = source:sub(index, index)
				if current == "\\" then
					buffer[#buffer + 1] = source:sub(index, index + 1)
					index += 2
				elseif current == "`" then
					index += 1
					break
				else
					if current == "\n" then
						line += 1
					end
					buffer[#buffer + 1] = current
					index += 1
				end
			end
			tokens[#tokens + 1] = { type = "template", value = table.concat(buffer), line = startLine }
		elseif digit(ch) or (ch == "." and digit(source:sub(index + 1, index + 1))) then
			local start = index
			while index <= length and source:sub(index, index):match("[%d%.]") do
				index += 1
			end
			if source:sub(index, index):match("[eE]") then
				index += 1
				if source:sub(index, index):match("[%+%-]") then
					index += 1
				end
				while digit(source:sub(index, index)) do
					index += 1
				end
			end
			push("number", tonumber(source:sub(start, index - 1)) or 0)
		elseif alpha(ch) then
			local start = index
			while index <= length and alnum(source:sub(index, index)) do
				index += 1
			end
			local word = source:sub(start, index - 1)
			push(KEYWORDS[word] and "keyword" or "ident", word)
		else
			local matched = false
			for _, operator in OPERATORS do
				if source:sub(index, index + #operator - 1) == operator then
					push("punc", operator)
					index += #operator
					matched = true
					break
				end
			end
			if not matched then
				push("punc", ch)
				index += 1
			end
		end
	end
	tokens[#tokens + 1] = { type = "eof", value = "", line = line }
	return tokens
end

-- Parser ----------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

local function newParser(tokens)
	return setmetatable({ tokens = tokens, index = 1 }, Parser)
end

function Parser:peek(offset)
	return self.tokens[self.index + (offset or 0)] or self.tokens[#self.tokens]
end

function Parser:at(tokenType, value)
	local token = self:peek()
	return token.type == tokenType and (value == nil or token.value == value)
end

function Parser:next()
	local token = self.tokens[self.index]
	self.index += 1
	return token
end

function Parser:match(tokenType, value)
	if self:at(tokenType, value) then
		return self:next()
	end
	return nil
end

function Parser:errorAt(token, message)
	error(string.format("JS syntax error: %s (line %d)", message, token and token.line or 0), 0)
end

function Parser:expect(tokenType, value)
	local token = self:peek()
	if token.type ~= tokenType or (value ~= nil and token.value ~= value) then
		self:errorAt(token, string.format("expected %s%s", tokenType, value and (" '" .. value .. "'") or ""))
	end
	return self:next()
end

function Parser:program()
	local statements = {}
	while not self:at("eof") do
		statements[#statements + 1] = self:statement()
	end
	return statements
end

function Parser:block()
	self:expect("punc", "{")
	local statements = {}
	while not self:at("punc", "}") do
		if self:at("eof") then
			self:errorAt(self:peek(), "unclosed block")
		end
		statements[#statements + 1] = self:statement()
	end
	self:expect("punc", "}")
	return { kind = "block", statements = statements }
end

function Parser:varDeclaration()
	local kind = self:next().value
	local declarations = {}
	repeat
		local name = self:expect("ident").value
		local value
		if self:match("punc", "=") then
			value = self:expression(1)
		end
		declarations[#declarations + 1] = { name = name, value = value, kind = kind }
	until not self:match("punc", ",")
	if self:at("punc", ";") then
		self:next()
	end
	return { kind = "var", declarations = declarations }
end

function Parser:functionRest()
	self:expect("punc", "(")
	local params = {}
	while not self:at("punc", ")") do
		params[#params + 1] = self:expect("ident").value
		if not self:match("punc", ",") then
			break
		end
	end
	self:expect("punc", ")")
	return params, self:block()
end

function Parser:arrowBody()
	if self:at("punc", "{") then
		return self:block()
	end
	return { kind = "expressionBody", expression = self:expression(1) }
end

function Parser:tryArrow()
	local start = self.index
	if not self:at("punc", "(") then
		return nil
	end
	self:next()
	local params = {}
	local ok = true
	while not self:at("punc", ")") do
		if self:at("ident") then
			params[#params + 1] = self:next().value
		else
			ok = false
			break
		end
		if not self:match("punc", ",") then
			break
		end
	end
	if ok and self:match("punc", ")") and self:at("punc", "=>") then
		self:next()
		return { kind = "arrow", params = params, body = self:arrowBody() }
	end
	self.index = start
	return nil
end

function Parser:templateParts(raw)
	local parts = {}
	local index = 1
	local function addText(text)
		if text ~= "" then
			parts[#parts + 1] = { text = text }
		end
	end
	while index <= #raw do
		local start = raw:find("${", index, true)
		if not start then
			addText(raw:sub(index))
			break
		end
		addText(raw:sub(index, start - 1))
		local depth = 1
		local cursor = start + 2
		local quote = nil
		while cursor <= #raw and depth > 0 do
			local ch = raw:sub(cursor, cursor)
			if quote then
				if ch == quote then
					quote = nil
				end
			elseif ch == '"' or ch == "'" then
				quote = ch
			elseif ch == "{" then
				depth += 1
			elseif ch == "}" then
				depth -= 1
			end
			cursor += 1
		end
		if depth > 0 then
			error("JS syntax error: unclosed template expression", 0)
		end
		local sub = newParser(tokenize(raw:sub(start + 2, cursor - 2)))
		parts[#parts + 1] = { expression = sub:expression(0) }
		index = cursor
	end
	return parts
end

function Parser:primary()
	local token = self:peek()

	if token.type == "number" or token.type == "string" then
		self:next()
		return { kind = "literal", value = token.value }
	elseif token.type == "template" then
		self:next()
		return { kind = "template", parts = self:templateParts(token.value) }
	elseif token.type == "keyword" then
		local value = token.value
		self:next()
		if value == "true" then
			return { kind = "literal", value = true }
		elseif value == "false" then
			return { kind = "literal", value = false }
		elseif value == "null" or value == "undefined" then
			return { kind = "literal", value = nil }
		elseif value == "this" then
			return { kind = "literal", value = nil }
		elseif value == "function" then
			local name
			if self:at("ident") then
				name = self:next().value
			end
			local params, body = self:functionRest()
			return { kind = "function", name = name, params = params, body = body }
		elseif value == "new" then
			self:errorAt(token, "'new' is not supported")
		else
			self:errorAt(token, "unexpected keyword '" .. value .. "'")
		end
	elseif token.type == "ident" then
		self:next()
		if self:at("punc", "=>") then
			self:next()
			return { kind = "arrow", params = { token.value }, body = self:arrowBody() }
		end
		return { kind = "identifier", name = token.value }
	elseif token.type == "punc" and token.value == "(" then
		local arrow = self:tryArrow()
		if arrow then
			return arrow
		end
		self:next()
		local expression = self:expression(0)
		self:expect("punc", ")")
		return expression
	elseif token.type == "punc" and token.value == "[" then
		self:next()
		local elements = {}
		while not self:at("punc", "]") do
			if self:match("punc", ",") then
				elements[#elements + 1] = { kind = "literal", value = nil }
			else
				elements[#elements + 1] = self:expression(1)
				if not self:match("punc", ",") then
					break
				end
			end
		end
		self:expect("punc", "]")
		return { kind = "array", elements = elements }
	elseif token.type == "punc" and token.value == "{" then
		self:next()
		local fields = {}
		while not self:at("punc", "}") do
			local key
			if self:at("ident") or self:at("string") or self:at("number") then
				key = tostring(self:next().value)
			else
				self:errorAt(self:peek(), "invalid object key")
			end
			local value
			if self:match("punc", ":") then
				value = self:expression(1)
			else
				value = { kind = "identifier", name = key }
			end
			fields[#fields + 1] = { key = key, value = value }
			if not self:match("punc", ",") then
				break
			end
		end
		self:expect("punc", "}")
		return { kind = "object", fields = fields }
	end

	self:errorAt(token, "unexpected token '" .. tostring(token.value) .. "'")
end

function Parser:postfix()
	local node = self:primary()
	while true do
		local token = self:peek()
		if token.type == "punc" and token.value == "." then
			self:next()
			local name = self:expect("ident").value
			node = { kind = "member", object = node, property = { kind = "literal", value = name } }
		elseif token.type == "punc" and token.value == "[" then
			self:next()
			local property = self:expression(0)
			self:expect("punc", "]")
			node = { kind = "member", object = node, property = property }
		elseif token.type == "punc" and token.value == "(" then
			self:next()
			local args = {}
			while not self:at("punc", ")") do
				args[#args + 1] = self:expression(1)
				if not self:match("punc", ",") then
					break
				end
			end
			self:expect("punc", ")")
			node = { kind = "call", callee = node, args = args }
		elseif token.type == "punc" and (token.value == "++" or token.value == "--") then
			self:next()
			node = { kind = "update", op = token.value, target = node, prefix = false }
		else
			break
		end
	end
	return node
end

function Parser:unary()
	local token = self:peek()
	if token.type == "punc" and (token.value == "!" or token.value == "-" or token.value == "+") then
		self:next()
		return { kind = "unary", op = token.value, value = self:unary() }
	elseif token.type == "punc" and (token.value == "++" or token.value == "--") then
		self:next()
		return { kind = "update", op = token.value, target = self:unary(), prefix = true }
	elseif token.type == "keyword" and token.value == "typeof" then
		self:next()
		return { kind = "unary", op = "typeof", value = self:unary() }
	end
	return self:postfix()
end

local PRECEDENCE = {
	["="] = 1,
	["+="] = 1,
	["-="] = 1,
	["*="] = 1,
	["/="] = 1,
	["||"] = 3,
	["&&"] = 4,
	["=="] = 5,
	["!="] = 5,
	["==="] = 5,
	["!=="] = 5,
	["<"] = 6,
	[">"] = 6,
	["<="] = 6,
	[">="] = 6,
	["+"] = 7,
	["-"] = 7,
	["*"] = 8,
	["/"] = 8,
	["%"] = 8,
}

function Parser:expression(minimum)
	local left = self:unary()
	while true do
		local token = self:peek()
		if token.type == "punc" and token.value == "?" then
			if (minimum or 0) >= 2 then
				break
			end
			self:next()
			local yes = self:expression(0)
			self:expect("punc", ":")
			local no = self:expression(2)
			left = { kind = "conditional", test = left, yes = yes, no = no }
		elseif token.type == "punc" and PRECEDENCE[token.value] then
			local precedence = PRECEDENCE[token.value]
			if precedence <= (minimum or 0) then
				break
			end
			self:next()
			local right
			if precedence == 1 then
				right = self:expression(precedence - 1)
				left = { kind = "assign", op = token.value, target = left, value = right }
			else
				right = self:expression(precedence)
				left = { kind = "binary", op = token.value, left = left, right = right }
			end
		else
			break
		end
	end
	return left
end

function Parser:ifStatement()
	self:next()
	self:expect("punc", "(")
	local test = self:expression(0)
	self:expect("punc", ")")
	local consequent = self:statement()
	local alternate
	if self:at("keyword", "else") then
		self:next()
		alternate = self:statement()
	end
	return { kind = "if", test = test, consequent = consequent, alternate = alternate }
end

function Parser:whileStatement()
	self:next()
	self:expect("punc", "(")
	local test = self:expression(0)
	self:expect("punc", ")")
	return { kind = "while", test = test, body = self:statement() }
end

function Parser:forStatement()
	local token = self:next()
	self:expect("punc", "(")
	if self:at("keyword", "let") or self:at("keyword", "const") or self:at("keyword", "var") then
		self:next()
		local name = self:expect("ident").value
		if self:at("ident", "of") or self:at("keyword", "of") then
			self:next()
			local iterable = self:expression(0)
			self:expect("punc", ")")
			return { kind = "forOf", name = name, iterable = iterable, body = self:statement() }
		elseif self:at("ident", "in") or self:at("keyword", "in") then
			self:next()
			local iterable = self:expression(0)
			self:expect("punc", ")")
			return { kind = "forIn", name = name, iterable = iterable, body = self:statement() }
		end
		self:expect("punc", "=")
		local init = self:expression(1)
		self:expect("punc", ";")
		local test
		if not self:at("punc", ";") then
			test = self:expression(0)
		end
		self:expect("punc", ";")
		local update
		if not self:at("punc", ")") then
			update = self:expression(0)
		end
		self:expect("punc", ")")
		return {
			kind = "for",
			name = name,
			init = init,
			test = test,
			update = update,
			body = self:statement(),
		}
	end
	self:errorAt(token, "for loops need 'let name = value; ...'")
end

function Parser:statement()
	local token = self:peek()
	if token.type == "punc" and token.value == "{" then
		return self:block()
	elseif token.type == "punc" and token.value == ";" then
		self:next()
		return { kind = "empty" }
	elseif token.type == "keyword" then
		local value = token.value
		if value == "let" or value == "const" or value == "var" then
			return self:varDeclaration()
		elseif value == "function" then
			self:next()
			local name = self:expect("ident").value
			local params, body = self:functionRest()
			return { kind = "function", name = name, params = params, body = body }
		elseif value == "if" then
			return self:ifStatement()
		elseif value == "while" then
			return self:whileStatement()
		elseif value == "for" then
			return self:forStatement()
		elseif value == "return" then
			self:next()
			local expression
			if not self:at("punc", ";") and not self:at("punc", "}") and not self:at("eof") then
				expression = self:expression(0)
			end
			if self:at("punc", ";") then
				self:next()
			end
			return { kind = "return", value = expression }
		elseif value == "break" then
			self:next()
			if self:at("punc", ";") then
				self:next()
			end
			return { kind = "break" }
		elseif value == "continue" then
			self:next()
			if self:at("punc", ";") then
				self:next()
			end
			return { kind = "continue" }
		elseif value == "switch" or value == "try" or value == "class" or value == "do" or value == "throw" or value == "delete" then
			self:errorAt(token, "'" .. value .. "' is not supported")
		end
	end

	local expression = self:expression(0)
	if self:at("punc", ";") then
		self:next()
	end
	return { kind = "expression", expression = expression }
end

-- Values and environments -----------------------------------------------

local NIL = { __nil = true }

local function truthy(value)
	if value == nil or value == NIL then
		return false
	end
	if value == false or value == 0 or value == "" then
		return false
	end
	return true
end

local function toNumber(value)
	if type(value) == "number" then
		return value
	elseif type(value) == "string" then
		return tonumber(value) or 0
	elseif type(value) == "boolean" then
		return value and 1 or 0
	end
	return 0
end

local function typeOf(value)
	if value == nil then
		return "undefined"
	end
	local valueType = type(value)
	if valueType == "table" then
		if isArray(value) then
			return "object"
		end
		return value.__jsFunction and "function" or "object"
	end
	return valueType
end

local Env = {}
Env.__index = Env

function Env.new(parent, host)
	return setmetatable({
		parent = parent,
		vars = {},
		declared = {},
		host = host or (parent and parent.host),
	}, Env)
end

function Env:get(name)
	local env = self
	while env do
		if env.declared[name] then
			return env.vars[name]
		end
		env = env.parent
	end
	local host = self.host
	if host and host[name] ~= nil then
		return host[name]
	end
	error("ReferenceError: " .. tostring(name) .. " is not defined", 0)
end

function Env:set(name, value)
	local env = self
	while env do
		if env.declared[name] then
			env.vars[name] = value
			return value
		end
		env = env.parent
	end
	self:declare(name, value)
	return value
end

function Env:declare(name, value)
	self.declared[name] = true
	self.vars[name] = value
end

local function pack(...)
	return table.pack(...)
end

local function callFunction(fn, args)
	if type(fn) ~= "function" then
		error("TypeError: " .. typeOf(fn) .. " is not a function", 0)
	end
	return fn(table.unpack(args, 1, args.n or #args))
end

local function arrayMember(array, key)
	if type(key) == "number" then
		return array[key + 1]
	end
	if key == "length" then
		return #array
	end
	if key == "push" then
		return function(...)
			for index = 1, select("#", ...) do
				array[#array + 1] = select(index, ...)
			end
			return #array
		end
	elseif key == "pop" then
		return function()
			local value = array[#array]
			array[#array] = nil
			return value
		end
	elseif key == "shift" then
		return function()
			return table.remove(array, 1)
		end
	elseif key == "unshift" then
		return function(value)
			table.insert(array, 1, value)
			return #array
		end
	elseif key == "indexOf" then
		return function(value)
			for index, item in array do
				if item == value then
					return index - 1
				end
			end
			return -1
		end
	elseif key == "includes" then
		return function(value)
			for _, item in array do
				if item == value then
					return true
				end
			end
			return false
		end
	elseif key == "join" then
		return function(separator)
			if separator == nil then
				separator = ","
			end
			local parts = {}
			for _, item in array do
				parts[#parts + 1] = item == nil and "" or tostring(item)
			end
			return table.concat(parts, tostring(separator))
		end
	elseif key == "forEach" then
		return function(fn)
			for index, item in table.clone(array) do
				callFunction(fn, pack(item, index - 1))
			end
		end
	elseif key == "map" then
		return function(fn)
			local out = Js.array({})
			for index, item in array do
				out[index] = callFunction(fn, pack(item, index - 1))
			end
			return out
		end
	elseif key == "filter" then
		return function(fn)
			local out = Js.array({})
			for index, item in array do
				if truthy(callFunction(fn, pack(item, index - 1))) then
					out[#out + 1] = item
				end
			end
			return out
		end
	elseif key == "find" then
		return function(fn)
			for index, item in array do
				if truthy(callFunction(fn, pack(item, index - 1))) then
					return item
				end
			end
			return nil
		end
	elseif key == "some" then
		return function(fn)
			for index, item in array do
				if truthy(callFunction(fn, pack(item, index - 1))) then
					return true
				end
			end
			return false
		end
	elseif key == "every" then
		return function(fn)
			for index, item in array do
				if not truthy(callFunction(fn, pack(item, index - 1))) then
					return false
				end
			end
			return true
		end
	elseif key == "slice" then
		return function(first, last)
			local length = #array
			first = first or 0
			if first < 0 then
				first = math.max(0, length + first)
			end
			last = last or length
			if last < 0 then
				last = length + last
			end
			local out = Js.array({})
			for index = first + 1, math.min(last, length) do
				out[#out + 1] = array[index]
			end
			return out
		end
	elseif key == "concat" then
		return function(other)
			local out = Js.array({})
			for _, item in array do
				out[#out + 1] = item
			end
			if isArray(other) then
				for _, item in other do
					out[#out + 1] = item
				end
			else
				out[#out + 1] = other
			end
			return out
		end
	elseif key == "reverse" then
		return function()
			local length = #array
			for index = 1, math.floor(length / 2) do
				array[index], array[length - index + 1] = array[length - index + 1], array[index]
			end
			return array
		end
	end
	return nil
end

local function stringMember(value, key)
	if key == "length" then
		return #value
	elseif key == "toUpperCase" then
		return function()
			return value:upper()
		end
	elseif key == "toLowerCase" then
		return function()
			return value:lower()
		end
	elseif key == "trim" then
		return function()
			return value:gsub("^%s+", ""):gsub("%s+$", "")
		end
	elseif key == "includes" then
		return function(needle)
			return value:find(tostring(needle), 1, true) ~= nil
		end
	elseif key == "startsWith" then
		return function(needle)
			needle = tostring(needle)
			return value:sub(1, #needle) == needle
		end
	elseif key == "endsWith" then
		return function(needle)
			needle = tostring(needle)
			return value:sub(-#needle) == needle
		end
	elseif key == "indexOf" then
		return function(needle)
			local start = value:find(tostring(needle), 1, true)
			return start and (start - 1) or -1
		end
	elseif key == "charAt" then
		return function(index)
			index = math.floor(toNumber(index)) + 1
			return value:sub(index, index)
		end
	elseif key == "substring" then
		return function(first, last)
			first = math.max(0, math.floor(toNumber(first or 0))) + 1
			last = last ~= nil and math.floor(toNumber(last)) + 1 or nil
			if last and last < first then
				first, last = last, first
			end
			return value:sub(first, last and (last - 1) or nil)
		end
	elseif key == "slice" then
		return function(first, last)
			local length = #value
			first = first or 0
			if first < 0 then
				first = math.max(0, length + first)
			end
			last = last or length
			if last < 0 then
				last = length + last
			end
			return value:sub(first + 1, math.min(last, length))
		end
	elseif key == "split" then
		return function(separator)
			local out = Js.array({})
			if separator == nil then
				out[1] = value
				return out
			end
			separator = tostring(separator)
			if separator == "" then
				for index = 1, #value do
					out[#out + 1] = value:sub(index, index)
				end
				return out
			end
			local start = 1
			while true do
				local found = value:find(separator, start, true)
				if not found then
					out[#out + 1] = value:sub(start)
					break
				end
				out[#out + 1] = value:sub(start, found - 1)
				start = found + #separator
			end
			return out
		end
	elseif key == "replace" then
		return function(needle, replacement)
			needle = tostring(needle)
			replacement = tostring(replacement)
			local start = value:find(needle, 1, true)
			if not start then
				return value
			end
			return value:sub(1, start - 1) .. replacement .. value:sub(start + #needle)
		end
	elseif key == "repeat" then
		return function(count)
			return value:rep(math.max(0, math.floor(toNumber(count))))
		end
	elseif key == "toString" then
		return function()
			return value
		end
	end
	return nil
end

local function numberMember(value, key)
	if key == "toFixed" then
		return function(digits)
			return string.format("%." .. math.floor(toNumber(digits)) .. "f", value)
		end
	elseif key == "toString" then
		return function()
			return tostring(value)
		end
	end
	return nil
end

local function getMember(object, key)
	if object == nil or object == NIL then
		error("TypeError: cannot read property '" .. tostring(key) .. "' of undefined", 0)
	end
	if type(object) == "string" then
		return stringMember(object, key)
	elseif type(object) == "number" then
		return numberMember(object, key)
	elseif type(object) == "table" then
		if isArray(object) then
			return arrayMember(object, key)
		end
		return object[key]
	end
	return nil
end

local function setMember(object, key, value)
	if type(object) ~= "table" then
		error("TypeError: cannot set property on " .. typeOf(object), 0)
	end
	if isArray(object) and type(key) == "number" then
		object[key + 1] = value
		return value
	end
	object[key] = value
	return value
end

local function evaluateBinary(op, a, b)
	if op == "+" then
		if type(a) == "string" or type(b) == "string" then
			return tostring(a == nil and "undefined" or a) .. tostring(b == nil and "undefined" or b)
		end
		return toNumber(a) + toNumber(b)
	elseif op == "-" then
		return toNumber(a) - toNumber(b)
	elseif op == "*" then
		return toNumber(a) * toNumber(b)
	elseif op == "/" then
		local divisor = toNumber(b)
		if divisor == 0 then
			return toNumber(a) == 0 and 0 / 0 or (toNumber(a) > 0 and math.huge or -math.huge)
		end
		return toNumber(a) / divisor
	elseif op == "%" then
		local divisor = toNumber(b)
		if divisor == 0 then
			return 0 / 0
		end
		return math.fmod(toNumber(a), divisor)
	elseif op == "==" or op == "===" then
		return a == b
	elseif op == "!=" or op == "!==" then
		return a ~= b
	elseif op == "<" then
		return a < b
	elseif op == ">" then
		return a > b
	elseif op == "<=" then
		return a <= b
	elseif op == ">=" then
		return a >= b
	end
	error("JS error: unsupported operator " .. tostring(op), 0)
end

-- Interpreter -----------------------------------------------------------

local evalExpression
local execStatement
local execBlock
local makeFunction

local function readTarget(node, env, context)
	if node.kind == "identifier" then
		return env:get(node.name)
	elseif node.kind == "member" then
		local object = evalExpression(node.object, env, context)
		local key = evalExpression(node.property, env, context)
		return getMember(object, key)
	end
	error("JS syntax error: invalid assignment target", 0)
end

local function writeTarget(node, value, env, context)
	if node.kind == "identifier" then
		return env:set(node.name, value)
	elseif node.kind == "member" then
		local object = evalExpression(node.object, env, context)
		local key = evalExpression(node.property, env, context)
		return setMember(object, key, value)
	end
	error("JS syntax error: invalid assignment target", 0)
end

makeFunction = function(node, closure, context)
	return function(...)
		local args = pack(...)
		local callEnv = Env.new(closure)
		for index, param in node.params do
			callEnv:declare(param, args[index])
		end
		context.steps += 1
		if context.steps > MAX_STEPS then
			error("JS error: script exceeded the step limit", 0)
		end
		if node.body.kind == "block" then
			local control = execBlock(node.body, callEnv, context)
			if control and control.type == "return" then
				return control.value
			end
			return nil
		end
		return evalExpression(node.body.expression, callEnv, context)
	end
end

evalExpression = function(node, env, context)
	local kind = node.kind
	if kind == "literal" then
		return node.value
	elseif kind == "identifier" then
		return env:get(node.name)
	elseif kind == "template" then
		local parts = {}
		for _, part in node.parts do
			if part.text then
				parts[#parts + 1] = part.text
			else
				local value = evalExpression(part.expression, env, context)
				parts[#parts + 1] = value == nil and "undefined" or tostring(value)
			end
		end
		return table.concat(parts)
	elseif kind == "array" then
		local out = Js.array({})
		for index, element in node.elements do
			out[index] = evalExpression(element, env, context)
		end
		return out
	elseif kind == "object" then
		local out = {}
		for _, field in node.fields do
			out[field.key] = evalExpression(field.value, env, context)
		end
		return out
	elseif kind == "function" or kind == "arrow" then
		return makeFunction(node, env, context)
	elseif kind == "member" then
		local object = evalExpression(node.object, env, context)
		local key = evalExpression(node.property, env, context)
		return getMember(object, key)
	elseif kind == "call" then
		local fn
		if node.callee.kind == "member" then
			local object = evalExpression(node.callee.object, env, context)
			local key = evalExpression(node.callee.property, env, context)
			fn = getMember(object, key)
		else
			fn = evalExpression(node.callee, env, context)
		end
		local args = { n = #node.args }
		for index, argNode in node.args do
			args[index] = evalExpression(argNode, env, context)
		end
		return callFunction(fn, args)
	elseif kind == "assign" then
		local value
		if node.op == "=" then
			value = evalExpression(node.value, env, context)
		else
			local current = readTarget(node.target, env, context)
			local right = evalExpression(node.value, env, context)
			value = evaluateBinary(node.op:sub(1, -2), current, right)
		end
		writeTarget(node.target, value, env, context)
		return value
	elseif kind == "update" then
		local current = readTarget(node.target, env, context)
		local nextValue = evaluateBinary(node.op == "++" and "+" or "-", current, 1)
		writeTarget(node.target, nextValue, env, context)
		return node.prefix and nextValue or current
	elseif kind == "unary" then
		if node.op == "!" then
			return not truthy(evalExpression(node.value, env, context))
		elseif node.op == "-" then
			return -toNumber(evalExpression(node.value, env, context))
		elseif node.op == "+" then
			return toNumber(evalExpression(node.value, env, context))
		elseif node.op == "typeof" then
			return typeOf(evalExpression(node.value, env, context))
		end
	elseif kind == "binary" then
		if node.op == "&&" then
			local left = evalExpression(node.left, env, context)
			if not truthy(left) then
				return left
			end
			return evalExpression(node.right, env, context)
		elseif node.op == "||" then
			local left = evalExpression(node.left, env, context)
			if truthy(left) then
				return left
			end
			return evalExpression(node.right, env, context)
		end
		return evaluateBinary(node.op, evalExpression(node.left, env, context), evalExpression(node.right, env, context))
	elseif kind == "conditional" then
		if truthy(evalExpression(node.test, env, context)) then
			return evalExpression(node.yes, env, context)
		end
		return evalExpression(node.no, env, context)
	end
	error("JS error: unsupported expression '" .. tostring(kind) .. "'", 0)
end

execBlock = function(block, env, context)
	for _, statement in block.statements do
		local control = execStatement(statement, env, context)
		if control then
			return control
		end
	end
	return nil
end

execStatement = function(node, env, context)
	context.steps += 1
	if context.steps > MAX_STEPS then
		error("JS error: script exceeded the step limit", 0)
	end

	local kind = node.kind
	if kind == "empty" then
		return nil
	elseif kind == "block" then
		return execBlock(node, Env.new(env), context)
	elseif kind == "expression" then
		evalExpression(node.expression, env, context)
		return nil
	elseif kind == "var" then
		for _, declaration in node.declarations do
			local value
			if declaration.value then
				value = evalExpression(declaration.value, env, context)
			end
			env:declare(declaration.name, value)
		end
		return nil
	elseif kind == "function" then
		env:declare(node.name, makeFunction(node, env, context))
		return nil
	elseif kind == "if" then
		if truthy(evalExpression(node.test, env, context)) then
			return execStatement(node.consequent, env, context)
		elseif node.alternate then
			return execStatement(node.alternate, env, context)
		end
		return nil
	elseif kind == "while" then
		while truthy(evalExpression(node.test, env, context)) do
			local control = execStatement(node.body, env, context)
			if control then
				if control.type == "break" then
					break
				elseif control.type == "return" then
					return control
				end
			end
		end
		return nil
	elseif kind == "for" then
		local loopEnv = Env.new(env)
		loopEnv:declare(node.name, evalExpression(node.init, env, context))
		while true do
			if node.test and not truthy(evalExpression(node.test, loopEnv, context)) then
				break
			end
			local control = execStatement(node.body, loopEnv, context)
			if control then
				if control.type == "break" then
					break
				elseif control.type == "return" then
					return control
				end
			end
			if node.update then
				evalExpression(node.update, loopEnv, context)
			end
		end
		return nil
	elseif kind == "forOf" then
		local iterable = evalExpression(node.iterable, env, context)
		local loopEnv = Env.new(env)
		local values = {}
		if isArray(iterable) then
			for index = 1, #iterable do
				values[#values + 1] = iterable[index]
			end
		elseif type(iterable) == "string" then
			for index = 1, #iterable do
				values[#values + 1] = iterable:sub(index, index)
			end
		elseif type(iterable) == "table" then
			for _, value in iterable do
				values[#values + 1] = value
			end
		else
			error("TypeError: " .. typeOf(iterable) .. " is not iterable", 0)
		end
		for _, value in values do
			-- A fresh binding per iteration: closures keep the value they saw.
			local iterationEnv = Env.new(env)
			iterationEnv:declare(node.name, value)
			local control = execStatement(node.body, iterationEnv, context)
			if control then
				if control.type == "break" then
					break
				elseif control.type == "return" then
					return control
				end
			end
		end
		return nil
	elseif kind == "forIn" then
		local iterable = evalExpression(node.iterable, env, context)
		local loopEnv = Env.new(env)
		local keys = {}
		if type(iterable) == "table" then
			for key in iterable do
				keys[#keys + 1] = key
			end
		end
		for _, key in keys do
			local iterationEnv = Env.new(env)
			iterationEnv:declare(node.name, key)
			local control = execStatement(node.body, iterationEnv, context)
			if control then
				if control.type == "break" then
					break
				elseif control.type == "return" then
					return control
				end
			end
		end
		return nil
	elseif kind == "return" then
		return { type = "return", value = node.value and evalExpression(node.value, env, context) or nil }
	elseif kind == "break" then
		return { type = "break" }
	elseif kind == "continue" then
		return { type = "continue" }
	end
	error("JS error: unsupported statement '" .. tostring(kind) .. "'", 0)
end

-- Runs a source string against a table of host globals.
-- Returns (ok, errorMessage).
function Js.run(source, host)
	local ok, result = pcall(function()
		local tokens = tokenize(tostring(source or ""))
		local parser = newParser(tokens)
		local program = parser:program()
		local env = Env.new(nil, host)
		local context = { steps = 0 }
		execBlock({ kind = "block", statements = program }, env, context)
	end)
	if not ok then
		return false, tostring(result)
	end
	return true, result
end

Js.tokenize = tokenize
Js.isArray = isArray
Js.truthy = truthy
Js.typeOf = typeOf

return Js
