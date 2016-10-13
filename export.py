#---------------------------------------------------------------
# Decompose layer params of a caffemodel to disk.
#---------------------------------------------------------------
import os
import caffe
import numpy as np
from parser import PrototxtParser


# 1. define .prototxt parser
parser = PrototxtParser('./model/net.t7.prototxt')


# 2. load caffe model
net = caffe.Net('./model/net.t7.prototxt', './model/net.t7.caffemodel', caffe.TEST)

# directory for saving layer params (weight + bias)
save_dir = './params/'
if not os.path.isdir(save_dir):
    os.mkdir(save_dir)

# log file storing layer info
logfile = open(save_dir+'net.log', 'w')

# write list content to file
def writeln(file, lst):
    content = ''
    for x in lst:
        content = content + str(x) + '\t'
    file.write(content+'\n')

# print list content to console
def println(lst):
    content = ''
    for x in lst:
        content = content + str(x) + ' '
    print(content)

# 3. dump layer params
print('\nexporting..')
layer_num = len(net.layers)
for i in range(layer_num):
    layer_type = net.layers[i].type
    layer_name = net._layer_names[i]

    if layer_type == 'InnerProduct':
        layer_weight = net.params[layer_name][0].data
        layer_bias = net.params[layer_name][1].data
        input_size = layer_weight.shape[1]
        output_size = layer_weight.shape[0]
        # save params
        np.save(save_dir+layer_name+'_weight', layer_weight)
        np.save(save_dir+layer_name+'_bias', layer_bias)
        # logging
        println(['==> layer', i, ': Linear [', str(input_size), '->', str(output_size), ']'])
        writeln(logfile, [i, 'Linear', layer_name])
    elif layer_type == 'ReLU':
        print('==> layer '+str(i)+' : ReLU')
        writeln(logfile, [i, 'ReLU', layer_name])
    elif layer_type == 'Flatten':
        print('==> layer '+str(i)+' : Flatten')
        writeln(logfile, [i, 'Flatten', layer_name])
    elif layer_type == 'Convolution':
        layer_weight = net.params[layer_name][0].data
        layer_bias = net.params[layer_name][1].data
        np.save(save_dir+layer_name+'_weight', layer_weight)
        np.save(save_dir+layer_name+'_bias', layer_bias)
        # parse conv params
        kW = parser.get_param(layer_name, 'convolution_param', 'kernel_w', 'kernel_size')
        kH = parser.get_param(layer_name, 'convolution_param', 'kernel_h', 'kernel_size')
        dW = parser.get_param(layer_name, 'convolution_param', 'stride_w', 'stride')
        dH = parser.get_param(layer_name, 'convolution_param', 'stride_h', 'stride')
        pW = parser.get_param(layer_name, 'convolution_param', 'pad_w', 'pad')
        pH = parser.get_param(layer_name, 'convolution_param', 'pad_h', 'pad')
        # logging
        println(['==> layer', i, ': Convolution [', kW,kH,dW,dH,pW,pH, ']'])
        writeln(logfile, [i, 'Convolution', layer_name, kW,kH,dW,dH,pW,pH])

logfile.close()







# net._layer_names[2]
# name = net._layer_names[2]


#
#
# w = net.params[name][0].data
# b = net.params[name][1].data
#
# w.shape
# b.shape
#
# name
#
# net.blobs[name]
