local ANIMATION_ID = "rbxassetid://115691907219551"  -- Your animation
local TAG_NAME = "AnimatedRig"  -- Tag to identify which rigs to animate

-- Function to animate a rig
local function animateRig(rig)
	local humanoid = rig:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local idleAnimation = Instance.new("Animation")
	idleAnimation.AnimationId = ANIMATION_ID

	local animTrack = animator:LoadAnimation(idleAnimation)
	animTrack.Looped = true
	animTrack.Priority = Enum.AnimationPriority.Idle
	animTrack:Play()

	print("Animated: " .. rig.Name)
end

-- Animate all rigs with the tag
local CollectionService = game:GetService("CollectionService")

for _, rig in pairs(CollectionService:GetTagged(TAG_NAME)) do
	animateRig(rig)
end

-- Animate new rigs that get tagged
CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(animateRig)--stuff 