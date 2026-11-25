--!nolint
-- Rauri :: element
-- A tiny virtual node. `kind` is a tag name ("frame", "text", ...) or a
-- component function called with (props, children).

local Element = {}

function Element.new(kind, props, children)
	return {
		__rauri = true,
		kind = kind,
		props = props or {},
		children = children or {},
		key = props and props.key or nil,
	}
end

function Element.isElement(value)
	return type(value) == "table" and value.__rauri == true
end

function Element.isComponent(node)
	return Element.isElement(node) and typeof(node.kind) == "function"
end

return Element
