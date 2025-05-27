#!/bin/lua
-- Basic neural network lib

local lib = {}

local function sigmoid(x)
    return 1 / (1 + math.exp(-x))
end

local function dsigmoid(y)
    return y * (1 - y)
end

local function forward_layer(input, layer)
    local output = {}
    for j = 1, #layer.weights do
        local sum = layer.biases[j]
        for k = 1, #input do
            sum = sum + input[k] * layer.weights[j][k]
        end
        output[j] = sigmoid(sum)
    end
    return output
end

function lib.new(opts)
    local net = {}
    net.input_size = opts.input or error("input size required")
    net.output_size = opts.output or error("output size required")
    net.hidden_sizes = opts.hidden or {}

    local function build_layers()
        net.layers = {}
        local prev_size = net.input_size
        for _, hsize in ipairs(net.hidden_sizes) do
            local layer = {weights = {}, biases = {}}
            for j = 1, hsize do
                layer.weights[j] = {}
                for k = 1, prev_size do
                    layer.weights[j][k] = (math.random() - 0.5) * 2
                end
                layer.biases[j] = (math.random() - 0.5) * 2
            end
            table.insert(net.layers, layer)
            prev_size = hsize
        end
        -- output layer
        local layer = {weights = {}, biases = {}}
        for j = 1, net.output_size do
            layer.weights[j] = {}
            for k = 1, prev_size do
                layer.weights[j][k] = (math.random() - 0.5) * 2
            end
            layer.biases[j] = (math.random() - 0.5) * 2
        end
        table.insert(net.layers, layer)
    end

    build_layers()

    function net.run(input)
        local outputs = {input}
        for _, layer in ipairs(net.layers) do
            local out = forward_layer(outputs[#outputs], layer)
            table.insert(outputs, out)
        end
        return outputs[#outputs]
    end

    local function build_layers_wrapper()
        build_layers()
    end

    local function train(inputs, targets, options)
        options = options or {}
        local epochs = options.epochs or 1000
        local lr = options.learning_rate or 0.1
        local allow_growth = options.allow_growth ~= false
        local growth_every = options.growth_check or 100
        local stagnation_threshold = options.stagnation or 3
        local enable_prune = options.prune or false
        local prune_every = options.prune_every or 500
        local prune_threshold = options.prune_threshold or 0.01

        local enable_weight_prune = options.weight_prune or false
        local weight_prune_every = options.weight_prune_every or 500
        local weight_prune_threshold = options.weight_prune_threshold or 0.01

        local best_loss = math.huge
        local stagnant_epochs = 0
        local activation_sums = {}

        if options.hidden then
            net.hidden_sizes = options.hidden
            build_layers_wrapper()
        end

        for epoch = 1, epochs do
            local total_loss = 0
            -- Reset activations sums
            for l = 1, #net.hidden_sizes do
                activation_sums[l] = activation_sums[l] or {}
                for n = 1, net.hidden_sizes[l] do
                    activation_sums[l][n] = 0
                end
            end

            for i = 1, #inputs do
                local input = inputs[i]
                local target = targets[i]

                local outputs = {input}
                for li, layer in ipairs(net.layers) do
                    local out = forward_layer(outputs[#outputs], layer)
                    if li <= #net.hidden_sizes then
                        for j = 1, #out do
                            activation_sums[li][j] = activation_sums[li][j] + math.abs(out[j])
                        end
                    end
                    table.insert(outputs, out)
                end

                local prediction = outputs[#outputs]
                for j = 1, #target do
                    total_loss = total_loss + (target[j] - prediction[j]) ^ 2
                end

                -- Backpropagation
                local errors = {}
                for l = #net.layers, 1, -1 do
                    local output = outputs[l + 1]
                    errors[l] = {}
                    for j = 1, #output do
                        if l == #net.layers then
                            errors[l][j] = (target[j] - output[j]) * dsigmoid(output[j])
                        else
                            local sum = 0
                            for k = 1, #net.layers[l + 1].weights do
                                sum = sum + net.layers[l + 1].weights[k][j] * errors[l + 1][k]
                            end
                            errors[l][j] = sum * dsigmoid(output[j])
                        end
                    end
                end

                for l = 1, #net.layers do
                    local layer = net.layers[l]
                    local input = outputs[l]
                    for j = 1, #layer.weights do
                        for k = 1, #input do
                            layer.weights[j][k] = layer.weights[j][k] + lr * errors[l][j] * input[k]
                        end
                        layer.biases[j] = layer.biases[j] + lr * errors[l][j]
                    end
                end
            end

            local avg_loss = total_loss / #inputs

            -- Auto-grow
            if epoch % growth_every == 0 and allow_growth then
                if avg_loss < best_loss - 1e-4 then
                    best_loss = avg_loss
                    stagnant_epochs = 0
                else
                    stagnant_epochs = stagnant_epochs + 1
                    if stagnant_epochs >= stagnation_threshold then
                        table.insert(net.hidden_sizes, math.max(2, net.hidden_sizes[#net.hidden_sizes] or 2))
                        build_layers_wrapper()
                        stagnant_epochs = 0
                        best_loss = math.huge
                    end
                end
            end

            -- Pruning neurons
            if enable_prune and epoch % prune_every == 0 then
                local changed = false
                for l = 1, #net.hidden_sizes do
                    local active = {}
                    local keep = 0
                    local count = #activation_sums[l]
                    for n = 1, count do
                        local avg = activation_sums[l][n] / #inputs
                        if avg > prune_threshold then
                            active[n] = true
                            keep = keep + 1
                        else
                            active[n] = false
                        end
                    end
                    if keep < count then
                        net.hidden_sizes[l] = keep
                        changed = true
                    end
                end
                if changed then
                    build_layers_wrapper()
                end
            end

            -- Weight pruning
            if enable_weight_prune and epoch % weight_prune_every == 0 then
                local pruned_count = 0
                for _, layer in ipairs(net.layers) do
                    for j = 1, #layer.weights do
                        for k = 1, #layer.weights[j] do
                            if math.abs(layer.weights[j][k]) < weight_prune_threshold then
                                layer.weights[j][k] = 0
                                pruned_count = pruned_count + 1
                            end
                        end
                    end
                end
                if pruned_count > 0 then
                end
            end
        end
    end

    function net.export()
        local export_data = {
            input_size = net.input_size,
            output_size = net.output_size,
            hidden_sizes = net.hidden_sizes,
            layers = {}
        }
        for i, layer in ipairs(net.layers) do
            export_data.layers[i] = {
                weights = layer.weights,
                biases = layer.biases
            }
        end
        return export_data
    end

    local function summary()
        local lines = {}
        table.insert(lines, "=== Neural Network Summary ===")
        table.insert(lines, "Input neurons: " .. net.input_size)
        for i, size in ipairs(net.hidden_sizes) do
            local layer = net.layers[i]
            local weights = #layer.weights
            local inputs = #layer.weights[1]
            table.insert(lines, string.format("Hidden Layer %d: %d neurons, weights: %d x %d", i, size, weights, inputs))
        end
        local out_layer = net.layers[#net.layers]
        table.insert(lines, string.format("Output Layer: %d neurons, weights: %d x %d", net.output_size, #out_layer.weights, #out_layer.weights[1]))

        local total_params = 0
        for _, layer in ipairs(net.layers) do
            for j = 1, #layer.weights do
                total_params = total_params + #layer.weights[j] + 1 -- +1 for bias
            end
        end
        table.insert(lines, "Total parameters (weights + biases): " .. total_params)
        table.insert(lines, "==============================")

        return table.concat(lines, "\n")
    end

    return {
        train = train,
        run = net.run,
        export = net.export,
        summary = summary
    }
end

return lib
