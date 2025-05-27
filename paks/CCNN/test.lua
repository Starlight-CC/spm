math.randomseed(os.time())

local nn = require("nn")

local net = nn.new{
    input = 3,
    hidden = {5},
    output = 2
}

local inputs, targets = {}, {}
for i = 1, 50 do
    local in_sample, out_sample = {}, {}
    for j = 1, 3 do in_sample[j] = math.random() end
    for k = 1, 2 do out_sample[k] = math.random() end
    inputs[i] = in_sample
    targets[i] = out_sample
end

net.train(inputs, targets, {
    epochs = 500,
    learning_rate = 0.2,
    allow_growth = true,
    growth_check = 100,
    stagnation = 3,
    prune = true,
    prune_every = 200,
    prune_threshold = 0.02,
    weight_prune = true,
    weight_prune_every = 200,
    weight_prune_threshold = 0.01
})

print(net.summary())
