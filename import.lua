------------------------------------------------------------------
-- Reconstruct a Torch model from saved layer params and log file.
------------------------------------------------------------------
require 'nn';
require 'xlua';
require 'paths';
require 'pl.tablex'
npy4th = require 'npy4th';

torch.setdefaulttensortype('torch.FloatTensor')

--------------------------------------------------------
-- Load saved weight & bias as .npy file.
--
function load_params(layer_name)
    local param_dir = './params/'
    assert(paths.dirp(param_dir), param_dir..' Not Exist!')
    local weight = npy4th.loadnpy(param_dir..layer_name..'.w.npy')
    local bias = npy4th.loadnpy(param_dir..layer_name..'.b.npy')
    return weight, bias
end

--------------------------------------------------------
-- New linear layer
--
function linear_layer(layer_name)
    -- TODO: automatically add nn.View(-1)
    -- load params
    local weight, bias = load_params(layer_name)
    -- define linear layer
    local inputSize = weight:size(2)
    local outputSize = weight:size(1)
    local layer = nn.Linear(inputSize, outputSize)
    -- copy params
    layer.weight:copy(weight)
    layer.bias:copy(bias)
    return layer
end

--------------------------------------------------------
-- New conv layer
--
function conv_layer(layer_name)
    -- load params
    local weight, bias = load_params(layer_name)
    -- define conv layer
    local nInputPlane = weight:size(2)
    local nOutputPlane = weight:size(1)
    local kW,kH = tonumber(splited[4]),tonumber(splited[5])
    local dW,dH = tonumber(splited[6]),tonumber(splited[7])
    local pW,pH = tonumber(splited[8]),tonumber(splited[9])
    local layer = nn.SpatialConvolution(nInputPlane, nOutputPlane, kW,kH,dW,dH,pW,pH)
    -- copy params
    layer.weight:copy(weight)
    layer.bias:copy(bias)
    return layer
end

--------------------------------------------------------
-- New bn layer
--
function bn_layer(layer_name)
    -- load params
    local running_mean, running_var = load_params(layer_name)
    -- define BN layer
    local nOutput = running_mean:size(1)
    local layer = nn.SpatialBatchNormalization(nOutput, nil, nil, false) -- No affine
    -- copy params
    layer.running_mean:copy(running_mean)
    layer.running_var:copy(running_var)
    return layer
end

--------------------------------------------------------
-- New pooling layer
--
function pooling_layer(layer_name)
    local pooling_type = splited[4] -- max or average
    local kW,kH = tonumber(splited[5]),tonumber(splited[6])
    local dW,dH = tonumber(splited[7]),tonumber(splited[8])
    local pW,pH = tonumber(splited[9]),tonumber(splited[10])

    local layer
    if pooling_type == '0' then
        layer = nn.SpatialMaxPooling(kW,kH,dW,dH,pW,pH):ceil()
    elseif pooling_type == '1' then
        layer = nn.SpatialAveragePooling(kW,kH,dW,dH,pW,pH):ceil()
    else
        error('[ERROR]Pooling type not supported!')
    end
    return layer
end

--------------------------------------------------------
-- New ReLU layer
--
function relu_layer()
    return nn.ReLU(true)
end

--------------------------------------------------------
-- New flatten layer
--
function flatten_layer()
    return nn.View(-1)
end

-- get layers from log
logfile = io.open('./params/net.log')

-- map layer_type to it's layer processing function
layerfunc = {
    InnerProduct = linear_layer,
    Convolution = conv_layer,
    BatchNorm = bn_layer,
    Pooling = pooling_layer,
    ReLU = relu_layer,
    Flatten = flatten_layer,
}

-- transfer saved params to net
net = nn.Sequential()
-- need flatten before adding any linear layer
flattened = false
print('importing..')
while true do
    local line = logfile:read('*l')
    if not line then break end

    splited = string.split(line, '\t')
    local layer_type = splited[2]
    local layer_name = splited[3]

    i = (i or 0) + 1
    print('==> layer '..i..': '..layer_type)

    -- if not flattened, add flatten layer before linear layer
    if not flattened and layer_type == 'InnerProduct' then
        net:add(nn.View(-1))
        flattened = true
    end

    -- contains flatten layer, no need to automatically add it
    if layer_type == 'Flatten' then flattened = true end

    local getlayer = layerfunc[layer_type]
    if not getlayer then error('[ERROR]'..layer_type..' not supported yet!') end

    -- add new layer
    local layer = getlayer(layer_name)
    net:add(layer)
end

print(net)
torch.save('net.t7', net)

-- test
print('testing..')
net:evaluate()
x = torch.randn(1,1,28,28)
y = net:float():forward(x:float())
print(y)
