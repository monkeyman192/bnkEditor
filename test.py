array = [0b010_11010, 0b101_01001, 0b011_01101, 0b011_11101]

out = []
initial_bits = 3
opp = 8 - initial_bits
mask = (2 << (8 - initial_bits - 1)) - 1

for i in range(len(array)):
    if not i:
        out.append(array[i] & mask)
    if i != len(array) - 1:
        end = array[i] >> opp
        start = (array[i + 1] & mask)
        out.append((start << initial_bits) + end)
    else:
        out.append(array[i] >> opp)
print('final')
for i in out:
    print(bin(i))
