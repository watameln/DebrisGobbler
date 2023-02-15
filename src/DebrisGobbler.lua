-- DebrisGobbler
-- by verret001

--[=[
	@class DebrisGobbler

	This module is a drop-in substitute for DebrisService that offers several significant performance and usability improvements.

	DebrisGobbler is much faster than DebrisService. While the DebrisService iterates through every item during each frame, resulting in up to 1000 iterations per frame or 60,000 iterations per second, this module only checks the nearest item to destruction per frame. 

	DebrisService has more problems that stem from this poor performance such as a preset limit on the number of debris items it can handle (which is 1000 by default), this causes problems such as Debris being destroyed before their expiry time. It also uses the old Roblox scheduler, which means 

	Despite these performance improvements, this module retains all of the advantages of DebrisService, such as not creating a new thread or coroutine for each new item and not holding onto destroyed items.

	To achieve this, the module utilizes a min-heap and some clever strategies to optimize the clearing of debris. The module is also strongly typed and offers some additional features on top of the original DebrisSevice such as DebrisGobbler:RemoveItem(Item).
]=]

local DebrisGobbler: DebrisGobbler = {}
local ExpiryReferences: ExpiryReferences = {}
local InstanceReferences: InstanceReferences = {}

local BinaryHeap = require(script.Parent.BinaryHeap)

local DebrisHeap = BinaryHeap.new(function(a, b)
	return (a < b)
end)

local pairs, clock, ceil, setmetatable = pairs, os.clock, math.ceil, setmetatable

game:GetService("RunService").Heartbeat:Connect(function()
	local Node: Node | nil, Value: number = DebrisHeap:peek()
	local currentTime: number = clock() + 1 / 60
	if Node and Value < currentTime then
		ExpiryReferences[Node] = nil
		DebrisHeap:pop()
		for Item: Instance, _ in pairs(Node) do
			-- mmm trash, I love trash
			Item:Destroy()
		end
	end
end)

--[=[
    Adds an item to be destroyed in a specific amount of time.

    @param Item Instance -- The instance to destroy
    @param Time number -- The delta time to destruction Default: 7
    @return number -- Returns the CPU time of destruction
]=]
function DebrisGobbler:AddItem(Item: Instance, Time: number?)
	assert(typeof(Item) == "Instance", "Invalid argument #1, expected type Instance")
	assert(typeof(Time) == "number" or Time == nil, "Invalid argument #2, expected type number?")

	-- We're locked to 60fps, so we can save on # of nodes by rounding to the next nearest frame.
	local ExpiryTime: number = ceil((clock() + (Time or 7)) * 60) / 60

	local Node: Node = ExpiryReferences[ExpiryTime]

	if Node == nil then
		Node = {}
		ExpiryReferences[ExpiryTime] = Node
		DebrisHeap:insert(ExpiryTime, Node)
	end

	InstanceReferences[Item] = Node
	Node[Item] = Item.Destroying:Connect(function()
		Node[Item] = nil
		InstanceReferences[Item] = nil
	end)

	return ExpiryTime
end

--[=[
    Removes an item from any destruction queues.

    @param Item Instance -- The instance to remove from the destruction queue
    @return boolean -- Returns if the item was removed from the queue
]=]
function DebrisGobbler:RemoveItem(Item: Instance)
	assert(typeof(Item) == "Instance", "Invalid argument #1, expected type Instance")
	local Node: Node = InstanceReferences[Item]
	if Node then
		Node[Item]:Disconnect()
		Node[Item] = nil
		InstanceReferences[Item] = nil
	end

	return not not Node
end

type Node = { [Instance]: RBXScriptConnection }
type ExpiryReferences = { [number]: Node }
type InstanceReferences = { [Instance]: Node }
type DebrisGobbler = typeof(DebrisGobbler)

return DebrisGobbler :: DebrisGobbler
