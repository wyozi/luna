
local luafier = {}

function luafier.listToLua(list)
	local buf = {}
	for i,snode in ipairs(list) do
		table.insert(buf, luafier.toLua(snode, buf))
	end
	return table.concat(buf, ", ")
end

function luafier.toLua(node)
	if node.type == "block" then
		local buf = {}
		for i,snode in ipairs(node) do
			table.insert(buf, luafier.toLua(snode, buf))
		end
		return table.concat(buf, "\n")
		
	elseif node.type == "local" then
		local s = "local " .. luafier.toLua(node[1])
		if node[2] then -- has explist
			s = s .. " = " .. luafier.toLua(node[2])
		end
		return s

	elseif node.type == "localfunc" then
		return
			"local function " .. luafier.toLua(node[1]) .. luafier.toLua(node[2])

	elseif node.type == "globalfunc" then
		return "function " .. luafier.toLua(node[1]) .. luafier.toLua(node[2])

	elseif node.type == "func" then
		return "function" .. luafier.toLua(node[1])

	elseif node.type == "sfunc" then
		return "function(" .. luafier.listToLua(node[1]) .. ") " .. luafier.toLua(node[2]) .. " end"

	elseif node.type == "funcbody" then
		return "(" .. luafier.toLua(node[1]) .. ") " .. luafier.toLua(node[2]) .. " end"

	elseif node.type == "assignment" then
		local op = node[1]

		if op == "=" then
			return luafier.toLua(node[2]) .. " = " .. luafier.toLua(node[3])
		else
			assert(#node[3] == 1, "assignment mod only works on 1-long explists currently")

			-- what kind of modification to do
			local modop = op:sub(1, 1)
			
			return luafier.toLua(node[2]) .. " = " .. luafier.toLua(node[2]) .. " " .. modop .. " (" .. luafier.toLua(node[3]) .. ")"
		end
	elseif node.type == "funccall" then
		return luafier.toLua(node[1]) .. "(" .. luafier.toLua(node[2]) .. ")"

	elseif node.type == "args" or node.type == "fieldlist" or node.type == "parlist" or node.type == "typednamelist" or node.type == "varlist" or node.type == "explist" then
		return luafier.listToLua(node)
		

	elseif node.type == "typedname" then
		return luafier.toLua(node[1])

	elseif node.type == "return" then
		return "return " .. luafier.toLua(node[1])
	elseif node.type == "break" then
		return "break " .. luafier.toLua(node[1])

	elseif node.type == "binop" then
		return luafier.toLua(node[2]) .. " " .. node[1] .. " " .. luafier.toLua(node[3])

	elseif node.type == "index" then
		return luafier.toLua(node[1]) .. "." .. luafier.toLua(node[2])

	elseif node.type == "tableconstructor" then
		return "{" .. luafier.toLua(node[1]) .. "}"
	elseif node.type == "field" then
		local key, val = node[1], node[2]
		if key then
			return luafier.toLua(key) .. " = " .. luafier.toLua(val)
		else
			return luafier.toLua(val)
		end

	elseif node.type == "if" then
		local s = "if " .. luafier.toLua(node[1]) .. " then " .. luafier.toLua(node[2])
		if node[3] then
			s = s .. " " .. luafier.toLua(node[3])
		end
		return s .. " end"
	elseif node.type == "ifassign" then
		-- Create a temporary variable name for the variable to be assigned before the if
		local origAssignedVarName = node[1][1][1][1].text -- ohgod
		local varName = "_ifa_" .. origAssignedVarName

		-- Set the assignment variable name to generated name
		node[1][1][1][1].text = varName

		-- Create a new if block that checks if varName is trueish
		local varId = { type = "identifier", text = varName }
		local checkerIf = { type = "if", varId, node[2] }

		-- Create a new local binding to restore the old name within the if scope and set it as the first code within if
		local restoreBinding = { type = "local", { type = "identifier", text = origAssignedVarName }, varId }
		table.insert(checkerIf[2], 1, restoreBinding)

		return
			luafier.toLua(node[1]) .. "\n" ..
			luafier.toLua(checkerIf)
	elseif node.type == "elseif" then
		local s = "elseif " .. luafier.toLua(node[1]) .. " then " .. luafier.toLua(node[2])
		if node[3] then
			s = s .. " " .. luafier.toLua(node[3])
		end
		return s
	elseif node.type == "else" then
		return "else " .. luafier.toLua(node[1])

	elseif node.type == "identifier" then
		return string.format("%s", node.text)
	elseif node.type == "literal" then
		return string.format("%s", node.text)
	elseif node.type == "number" then
		return string.format("%d", node.text)
	else
		error("unhandled ast node " .. node.type)
	end
end

return luafier