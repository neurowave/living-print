"""Extract the shoe mesh and textures from the Khronos MaterialsVariantsShoe GLB.

Writes the asset files the scene loads (shoeVertices.bin, shoeIndices.bin, shoeColor.jpeg,
shoeNormal.jpeg, shoeOrm.jpeg) into the project folder. Positions, normals, UVs, indices and
textures are copied unchanged; each vertex gets one extra float that tags its material region.

    python3 tools/prepare_shoe.py tools/MaterialsVariantsShoe.glb
"""
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'tools' / 'MaterialsVariantsShoe.glb'
glb = source.read_bytes()
length = struct.unpack_from('<I', glb, 12)[0]
doc = json.loads(glb[20:20 + length])
binary = glb[28 + length:]


def accessor(index):
    a = doc['accessors'][index]
    v = doc['bufferViews'][a['bufferView']]
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
    fmt = {5126: 'f', 5125: 'I', 5123: 'H'}[a['componentType']]
    size = struct.calcsize('<' + fmt * count)
    start = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = v.get('byteStride', size)
    return [struct.unpack_from('<' + fmt * count, binary, start + i * stride) for i in range(a['count'])]


def region(i):
    # Component boundaries in the source mesh: 1 laces, 0 knit upper, 2 eyelets, 3 sole,
    # 4 heel patch and side appliques.
    return 1 if i < 1963 else 2 if 8027 <= i < 10331 else 3 if 10331 <= i < 11697 else 4 if i >= 11697 else 0


p = doc['meshes'][0]['primitives'][0]
positions = accessor(p['attributes']['POSITION'])
normals = accessor(p['attributes']['NORMAL'])
uvs = accessor(p['attributes']['TEXCOORD_0'])
indices = accessor(p['indices'])
(ROOT / 'shoeVertices.bin').write_bytes(b''.join(
    struct.pack('<9f', *xyz, *n, *uv, region(i)) for i, (xyz, n, uv) in enumerate(zip(positions, normals, uvs))))
(ROOT / 'shoeIndices.bin').write_bytes(b''.join(struct.pack('<I', i[0]) for i in indices))

images = {'diffuseMidnight.jpg': 'shoeColor.jpeg', 'normal.jpg': 'shoeNormal.jpeg',
          'occlusionRougnessMetalness.jpg': 'shoeOrm.jpeg'}
for item in doc['images']:
    if item['name'] in images:
        view = doc['bufferViews'][item['bufferView']]
        start = view.get('byteOffset', 0)
        (ROOT / images[item['name']]).write_bytes(binary[start:start + view['byteLength']])
print(f'{len(positions)} vertices, {len(indices) // 3} triangles, {len(images)} textures')
