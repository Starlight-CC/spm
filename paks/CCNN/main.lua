local CCNN = {}

local function sigmoid(x) return 1 / (1 + math.exp(-x)) end
local function dsigmoid(y) return y * (1 - y) end

local function randmat(rows, cols)
    local m = {}
    for i = 1, rows do
        m[i] = {}
        for j = 1, cols do
            m[i][j] = (math.random() - 0.5) * 2
        end
    end
    return m
end

local function forward(layers, input)
    local activations = {input}
    for _, layer in ipairs(layers) do
        local next_input = {}
        for i = 1, #layer.weights do
            local sum = layer.biases[i]
            for j = 1, #input do
                sum = sum + layer.weights[i][j] * input[j]
            end
            next_input[i] = sigmoid(sum)
        end
        table.insert(activations, next_input)
        input = next_input
    end
    return activations
end

local function train_net(self, inputs, targets, opts)
    local opt = {
        epochs = opts.epochs or 100,
        learning_rate = opts.learning_rate or 0.1,
        allow_growth = opts.allow_growth,
        growth_check = opts.growth_check or 20,
        stagnation = opts.stagnation or 3,
        prune = opts.prune,
        prune_every = opts.prune_every or 100,
        prune_threshold = opts.prune_threshold or 0.01,
        weight_prune = opts.weight_prune,
        weight_prune_every = opts.weight_prune_every or 100,
        weight_prune_threshold = opts.weight_prune_threshold or 0.001,
    }

    local last_error, stagnant = math.huge, 0

    for epoch = 1, opt.epochs do
        local total_error = 0

        for i, input in ipairs(inputs) do
            local target = targets[i]
            local acts = forward(self.layers, input)
            local deltas = {}
            for l = #self.layers, 1, -1 do
                deltas[l] = {}
                for j = 1, #self.layers[l].biases do
                    local out = acts[l+1][j]
                    if l == #self.layers then
                        deltas[l][j] = (target[j] - out) * dsigmoid(out)
                    else
                        local sum = 0
                        for k = 1, #deltas[l+1] do
                            sum = sum + deltas[l+1][k] * self.layers[l+1].weights[k][j]
                        end
                        deltas[l][j] = sum * dsigmoid(out)
                    end
                end
            end

            for l = 1, #self.layers do
                local input_a = acts[l]
                for j = 1, #self.layers[l].weights do
                    for k = 1, #input_a do
                        self.layers[l].weights[j][k] = self.layers[l].weights[j][k] + opt.learning_rate * deltas[l][j] * input_a[k]
                    end
                    self.layers[l].biases[j] = self.layers[l].biases[j] + opt.learning_rate * deltas[l][j]
                end
            end

            for j = 1, #target do
                local e = target[j] - acts[#acts][j]
                total_error = total_error + e * e
            end
        end

        total_error = total_error / #inputs

        if opt.allow_growth and epoch % opt.growth_check == 0 then
            if math.abs(total_error - last_error) < 1e-4 then
                stagnant = stagnant + 1
                if stagnant >= opt.stagnation then
                    local last_hidden = self.layers[#self.layers - 1]
                    local new_weights = {}
                    for _ = 1, #last_hidden.weights[1] do
                        table.insert(new_weights, (math.random() - 0.5) * 2)
                    end
                    table.insert(last_hidden.weights, new_weights)
                    table.insert(last_hidden.biases, 0)
                    for _, out in ipairs(self.layers[#self.layers].weights) do
                        table.insert(out, (math.random() - 0.5) * 2)
                    end
                    stagnant = 0
                end
            else
                stagnant = 0
            end
            last_error = total_error
        end

        if opt.prune and epoch % opt.prune_every == 0 then
            local h = self.layers[#self.layers - 1]
            local keep = {}
            for i, b in ipairs(h.biases) do
                if math.abs(b) > opt.prune_threshold then
                    table.insert(keep, i)
                end
            end
            local new_w, new_b = {}, {}
            for _, i in ipairs(keep) do
                table.insert(new_w, h.weights[i])
                table.insert(new_b, h.biases[i])
            end
            h.weights, h.biases = new_w, new_b
            for _, out in ipairs(self.layers[#self.layers].weights) do
                while #out > #new_w do table.remove(out) end
            end
        end

        if opt.weight_prune and epoch % opt.weight_prune_every == 0 then
            for _, layer in ipairs(self.layers) do
                for i = 1, #layer.weights do
                    for j = 1, #layer.weights[i] do
                        if math.abs(layer.weights[i][j]) < opt.weight_prune_threshold then
                            layer.weights[i][j] = 0
                        end
                    end
                end
            end
        end
    end
end

local function run_net(self, input)
    local out = forward(self.layers, input)
    return out[#out]
end

local function summary_net(self)
    local out = {}
    table.insert(out, "=== CCNN Summary ===")
    table.insert(out, "Input neurons: " .. self.input_size)
    for i = 1, #self.hidden_sizes do
        local layer = self.layers[i]
        table.insert(out, string.format("Hidden Layer %d: %d neurons, weights: %d x %d", i, #layer.biases, #layer.biases, #layer.weights[1]))
    end
    local last = self.layers[#self.layers]
    table.insert(out, string.format("Output Layer: %d neurons, weights: %d x %d", #last.biases, #last.biases, #last.weights[1]))
    local total = 0
    for _, l in ipairs(self.layers) do
        total = total + #l.biases * (#l.weights[1] + 1)
    end
    table.insert(out, "Total parameters (weights + biases): " .. total)
    table.insert(out, "==============================")
    return table.concat(out, "\n")
end

local function export_net(self)
    return {
        input_size = self.input_size,
        hidden_sizes = self.hidden_sizes,
        output_size = self.output_size,
        layers = self.layers
    }
end

function CCNN.new(cfg)
    local net = {
        input_size = cfg.input,
        hidden_sizes = cfg.hidden or {},
        output_size = cfg.output,
        layers = {}
    }

    local sizes = {net.input_size, table.unpack(net.hidden_sizes), net.output_size}
    for i = 1, #sizes - 1 do
        table.insert(net.layers, {
            weights = randmat(sizes[i+1], sizes[i]),
            biases = {}
        })
        for j = 1, sizes[i+1] do table.insert(net.layers[#net.layers].biases, 0) end
    end

    net.train = train_net
    net.run = run_net
    net.export = export_net
    net.summary = summary_net

    return net
end

function CCNN.load(data)
    local net = {
        input_size = data.input_size,
        hidden_sizes = data.hidden_sizes,
        output_size = data.output_size,
        layers = data.layers
    }

    net.train = train_net
    net.run = run_net
    net.export = export_net
    net.summary = summary_net

    return net
end

return CCNN