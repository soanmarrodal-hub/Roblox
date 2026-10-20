"""Per-hero paint / rig specs for the 12 launch heroes (raw FBX coords: x right, y back, z up; front faces -y)."""

SPECS = {}

# ----------------------------------------------------------------------------------------------- Leafin
SPECS['Leafin'] = dict(
    height=1.2,
    palette={
        'fur': ('#FFF7E6', 'fur'), 'leaflight': ('#D6EFB3', 'leaf'), 'leaf': ('#7ED957', 'leaf'),
        'leafdark': ('#2E7D32', 'leaf'), 'bark': ('#8B5E3C', 'wood'), 'crystal': ('#6CFF7A', 'crystal'),
        'inner': ('#FFE3B8', 'fur'),
    },
    allow_default=['fur', 'leaflight', 'leaf', 'leafdark'],
    parts={
        0: ('leaf', 'Sprout R', ['leaf', 'leaflight']), 1: ('leafdark', 'Cuff R', ['leaf', 'leafdark']),
        2: ('leaf', 'Tail', ['leaf', 'leaflight', 'leafdark']), 3: ('leafdark', 'Foot R', ['leaf', 'leafdark', 'bark']),
        4: ('leafdark', 'Foot L', ['leaf', 'leafdark', 'bark']), 5: ('fur', 'Leg R', ['fur', 'leaf']),
        6: ('fur', 'Torso', ['fur', 'leaf']), 7: ('leafdark', 'Cuff L', ['leaf', 'leafdark']),
        8: ('fur', 'Leg L', ['fur', 'leaf']), 9: ('leaf', 'Crest', ['leaf', 'leaflight']),
        10: ('leaf', 'Ear R', ['leaf', 'leaflight', 'inner']), 11: ('leaf', 'Sprout L', ['leaf', 'leaflight']),
        12: ('fur', 'Arm R', ['fur']), 13: ('fur', 'Back', ['fur', 'leaf', 'leafdark']),
        14: ('leaf', 'Ear L', ['leaf', 'leaflight', 'inner']), 15: ('fur', 'Arm L', ['fur']),
        16: ('fur', 'Head', 'solid'), 17: ('leaf', 'Collar', ['leaf', 'leafdark', 'leaflight']),
        18: ('leaf', 'Shoulder leaf', ['leaf', 'leafdark']), 19: ('leaf', 'Cheek leaf', ['leaf', 'leaflight']),
    },
    groups={0: 'Head', 9: 'Head', 10: 'EarR', 11: 'Head', 14: 'EarL', 16: 'Head', 19: 'Head', 13: 'Head',
            12: 'ArmR', 1: 'ArmR', 15: 'ArmL', 7: 'ArmL', 5: 'LegR', 3: 'LegR', 8: 'LegL', 4: 'LegL', 2: 'Tail'},
    parents={'EarL': 'Head', 'EarR': 'Head'},
    overrides=[
        dict(shape='sphere', c=(-0.02, -0.19, 0.36), r=0.035, label='crystal', parts=[17]),  # collar crystal
        dict(shape='z', z=(0.0, 0.52), label='leaf', parts=[13], back=-2.0),
    ],
    decals=[
        dict(kind='anime', part=16, c=(-0.139, 0.538), r=(0.050, 0.050), iris='#43C64B', tilt=0),
        dict(kind='anime', part=16, c=(0.104, 0.538), r=(0.050, 0.050), iris='#43C64B', tilt=0),
        dict(kind='gem', part=16, c=(-0.016, 0.617), r=(0.024, 0.034), color='#5CFF6E'),
        dict(kind='mouth', part=16, c=(-0.018, 0.479), r=(0.034, 0.012), width=0.22),
        dict(kind='blush', part=16, c=(-0.181, 0.488), r=(0.034, 0.022)),
        dict(kind='blush', part=16, c=(0.141, 0.488), r=(0.034, 0.022)),
        dict(kind='spot', part=16, c=(-0.099, 0.662), r=(0.03, 0.014), color='#58C24F', tilt=-30, soft=8),
        dict(kind='spot', part=16, c=(0.058, 0.662), r=(0.03, 0.014), color='#58C24F', tilt=30, soft=8),
        dict(kind='spot', part=16, c=(-0.088, 0.615), r=(0.012, 0.008), color='#58C24F', tilt=-30, soft=8),
        dict(kind='spot', part=16, c=(0.052, 0.615), r=(0.012, 0.008), color='#58C24F', tilt=30, soft=8),
    ],
    glow={},
)

# ----------------------------------------------------------------------------------------------- Thornix
SPECS['Thornix'] = dict(
    height=1.8,
    palette={
        'barkdark': ('#3B1F17', 'bark'), 'bark': ('#6B2E1E', 'bark'), 'leafdark': ('#2E6B2D', 'leaf'),
        'leaf': ('#3FA661', 'leaf'), 'mask': ('#E5E1DB', 'mask'), 'red': ('#FF3B3B', 'crystal'),
    },
    snap_palette={'leaf': '#6FBF3A', 'leafdark': '#3E8A2A', 'bark': '#6B3A22', 'barkdark': '#3B1F17'},
    parts={
        0: ('bark', 'Fist L', ['barkdark', 'bark', 'leafdark', 'leaf', 'red']),
        1: ('bark', 'Head/antlers', ['barkdark', 'bark', 'leafdark', 'leaf', 'mask', 'red']),
        2: ('bark', 'Fist R', ['barkdark', 'bark', 'leafdark', 'leaf', 'red']),
        3: ('bark', 'Leg L', ['barkdark', 'bark', 'leafdark', 'leaf', 'red']),
        4: ('bark', 'Leg R', ['barkdark', 'bark', 'leafdark', 'leaf', 'red']),
        5: ('bark', 'Thigh R', ['barkdark', 'bark', 'leafdark', 'leaf', 'red']),
        6: ('mask', 'Shoulder plate', 'solid'),
        7: ('bark', 'Thigh L', ['barkdark', 'bark', 'leafdark', 'leaf', 'red']),
    },
    groups={0: 'ArmL', 2: 'ArmR', 3: 'LegL', 7: 'LegL', 4: 'LegR', 5: 'LegR'},
    overrides=[
        dict(shape='z', z=(0.80, 2.0), label='bark', parts=[1], **{'from': ['mask', 'leaf', 'leafdark']}),
    ],
    decals=[],
    glow={},
)

# ----------------------------------------------------------------------------------------------- Bramble
SPECS['Bramble'] = dict(
    height=1.6,
    palette={'leafdark': ('#3E6B34', 'leaf'), 'moss': ('#6F8F3A', 'leaf'), 'barklight': ('#B1784E', 'bark'),
             'bark': ('#7A4B2E', 'bark'), 'green': ('#2D5E3A', 'leaf'), 'crystal': ('#9EF06A', 'crystal')},
    snap_palette={'moss': '#7FC03A', 'leafdark': '#4E8F2E'},
    allow_default=['leafdark', 'moss', 'barklight', 'bark', 'green', 'crystal'],
    parts={0: ('barklight', 'Fist L', ['barklight', 'bark', 'moss', 'leafdark']), 1: ('barklight', 'Face', ['barklight', 'bark']),
           2: ('barklight', 'Leg R', ['barklight', 'bark', 'moss', 'leafdark']), 3: ('barklight', 'Fist R', ['barklight', 'bark', 'moss', 'leafdark']),
           4: ('barklight', 'Torso', ['barklight', 'bark', 'moss', 'leafdark', 'crystal']), 5: ('moss', 'Shoulder L', ['moss', 'leafdark', 'barklight']),
           6: ('barklight', 'Leg L', ['barklight', 'bark', 'moss', 'leafdark']), 7: ('bark', 'Foot L', ['barklight', 'bark', 'moss']),
           8: ('moss', 'Head foliage', ['moss', 'leafdark', 'green']), 9: ('moss', 'Foliage R', ['moss', 'leafdark', 'green']),
           10: ('moss', 'Foliage L', ['moss', 'leafdark', 'green']), 11: ('moss', 'Belt leaf', ['moss', 'leafdark'])},
    groups={0: 'ArmL', 3: 'ArmR', 1: 'Head', 8: 'Head', 2: 'LegR', 6: 'LegL', 7: 'LegL'},
    overrides=[dict(shape='sphere', c=(0.0, -0.17, 0.52), r=0.045, label='crystal', parts=[4])],
    decals=[dict(kind='anime', part=1, c=(-0.047, 0.729), r=(0.032, 0.021), iris='#2B1D12', line='#120C08', tilt=-12),
            dict(kind='anime', part=1, c=(0.055, 0.729), r=(0.032, 0.021), iris='#2B1D12', line='#120C08', tilt=12)],
    glow={},
)

# ----------------------------------------------------------------------------------------------- Cylla
SPECS['Cylla'] = dict(
    height=1.2,
    palette={'hairdark': ('#0F3B2E', 'hair'), 'hair': ('#2E7D32', 'hair'), 'leaf': ('#A7D85E', 'leaf'),
             'gold': ('#FFD98F', 'gold'), 'petal': ('#F9E4F2', 'flower'), 'purple': ('#8A3FCC', 'cloth'),
             'skin': ('#FFE2CC', 'skin'), 'pink': ('#F48FB1', 'flower'), 'wood': ('#7A4B2E', 'wood')},
    snap_palette={'hair': '#3E9A3A', 'leaf': '#9BD34E'},
    parts={0: ('hair', 'Hair+crown', ['hairdark', 'hair', 'leaf', 'petal', 'pink', 'wood']), 1: ('hair', 'Boot L', ['hairdark', 'hair', 'leaf', 'wood']),
           2: ('hair', 'Boot R', ['hairdark', 'hair', 'leaf', 'wood']), 3: ('hair', 'Skirt', ['hairdark', 'hair', 'leaf', 'petal', 'pink']),
           4: ('skin', 'Face', 'solid'), 5: ('skin', 'Legs', ['skin', 'hair', 'hairdark']),
           6: ('wood', 'Bow', ['wood', 'gold', 'pink', 'leaf']), 7: ('skin', 'Hand L', ['skin', 'hair']), 8: ('skin', 'Hand R', ['skin', 'hair']),
           9: ('wood', 'Arrow', ['wood', 'gold', 'leaf', 'pink']), 10: ('hair', 'Sleeve R', ['hair', 'hairdark', 'leaf', 'petal']),
           11: ('hair', 'Sleeve L', ['hair', 'hairdark', 'leaf', 'petal']), 12: ('leaf', 'Back leaf', ['leaf', 'hair']),
           13: ('hair', 'Torso', ['hair', 'hairdark', 'leaf', 'wood', 'pink'])},
    groups={0: 'Body', 4: 'Head', 7: 'ArmL', 11: 'ArmL', 6: 'Weapon', 8: 'ArmR', 10: 'ArmR', 9: 'WeaponR', 1: 'LegL', 2: 'LegR'},
    parents={'Weapon': 'ArmL', 'WeaponR': 'ArmR'},
    overrides=[],
    decals=[dict(kind='anime', part=4, c=(-0.048, 0.712), r=(0.029, 0.026), iris='#86C43E', tilt=-6),
            dict(kind='anime', part=4, c=(0.060, 0.712), r=(0.029, 0.026), iris='#86C43E', tilt=6),
            dict(kind='blush', part=4, c=(-0.07, 0.676), r=(0.02, 0.012), alpha=0.4),
            dict(kind='blush', part=4, c=(0.082, 0.676), r=(0.02, 0.012), alpha=0.4)],
    glow={},
)

# ----------------------------------------------------------------------------------------------- Lumora
SPECS['Lumora'] = dict(
    height=1.4,
    palette={'cream': ('#FFF8D6', 'hair'), 'yellow': ('#FFE066', 'crystal'), 'leaf': ('#A8D06A', 'leaf'),
             'leafdark': ('#4E8F4A', 'leaf'), 'gold': ('#B48F3C', 'gold'), 'light': ('#FFF3A8', 'cloth'), 'skin': ('#FFE6D2', 'skin')},
    snap_palette={'yellow': '#E8E05A'},
    parts={0: ('yellow', 'Wing L low', ['yellow', 'leaf']), 1: ('yellow', 'Wing R low', ['yellow', 'leaf']),
           2: ('yellow', 'Wing L up', ['yellow', 'leaf']), 3: ('yellow', 'Wing R up', ['yellow', 'leaf']),
           4: ('cream', 'Skirt leaf R', ['cream', 'leaf', 'light']), 5: ('leafdark', 'Arm R', ['leafdark', 'leaf', 'skin', 'gold']),
           6: ('cream', 'Hair', ['cream', 'light', 'gold', 'leaf']), 7: ('yellow', 'Wing R mid', ['yellow', 'leaf']),
           8: ('yellow', 'Wing L mid', ['yellow', 'leaf']), 9: ('gold', 'Boot L', ['gold', 'leafdark', 'cream']),
           10: ('cream', 'Hair flower', ['cream', 'gold', 'leaf']), 11: ('leafdark', 'Arm L', ['leafdark', 'leaf', 'skin', 'gold']),
           12: ('cream', 'Skirt leaf L', ['cream', 'leaf', 'light']), 13: ('gold', 'Boot R', ['gold', 'leafdark', 'cream']),
           14: ('light', 'Chest', ['light', 'cream', 'yellow']), 15: ('cream', 'Skirt', ['cream', 'light', 'leaf', 'gold']),
           16: ('skin', 'Face', 'solid'), 17: ('leafdark', 'Torso', ['leafdark', 'leaf', 'gold', 'cream'])},
    groups={0: 'WingL', 2: 'WingL', 8: 'WingL', 1: 'WingR', 3: 'WingR', 7: 'WingR', 5: 'ArmR', 11: 'ArmL', 9: 'LegL', 13: 'LegR', 16: 'Head'},
    overrides=[dict(shape='sphere', c=(0.0, -0.17, 0.43), r=0.03, label='yellow', parts=[17, 14])],
    decals=[dict(kind='anime', part=16, c=(-0.051, 0.674), r=(0.025, 0.021), iris='#E6A93A', tilt=-5),
            dict(kind='anime', part=16, c=(0.046, 0.674), r=(0.025, 0.021), iris='#E6A93A', tilt=5),
            dict(kind='blush', part=16, c=(-0.066, 0.645), r=(0.017, 0.01), alpha=0.35),
            dict(kind='blush', part=16, c=(0.061, 0.645), r=(0.017, 0.01), alpha=0.35)],
    glow={},
)

# ----------------------------------------------------------------------------------------------- Verdantis
SPECS['Verdantis'] = dict(
    height=3.5,
    palette={'leafdark': ('#2E7D32', 'leaf'), 'leaf': ('#7ED957', 'leaf'), 'mint': ('#B9F6D2', 'crystal'),
             'cream': ('#F3EBD8', 'mask'), 'bark': ('#8B5E3C', 'bark'), 'pink': ('#FF6FB5', 'flower'), 'barkdark': ('#5A3A22', 'bark')},
    snap_palette={'leaf': '#8FD448', 'leafdark': '#3D8A2A'},
    parts={0: ('bark', 'Arm R', ['bark', 'barkdark', 'leaf', 'leafdark', 'pink']), 1: ('bark', 'Arm L', ['bark', 'barkdark', 'leaf', 'leafdark', 'pink']),
           2: ('leaf', 'Tree 1', ['leaf', 'leafdark', 'bark', 'pink']), 3: ('leaf', 'Tree 2', ['leaf', 'leafdark', 'bark', 'pink']),
           4: ('leaf', 'Head+shoulders', ['leaf', 'leafdark', 'bark', 'barkdark', 'cream', 'pink', 'mint']),
           5: ('leaf', 'Tree 3', ['leaf', 'leafdark', 'bark', 'pink']), 6: ('bark', 'Leg L', ['bark', 'barkdark', 'leaf', 'leafdark', 'pink']),
           7: ('bark', 'Leg R', ['bark', 'barkdark', 'leaf', 'leafdark', 'pink']), 8: ('bark', 'Torso', ['bark', 'barkdark', 'leaf', 'leafdark', 'cream', 'mint', 'pink']),
           9: ('leaf', 'Tree 4', ['leaf', 'leafdark', 'bark', 'pink']), 10: ('bark', 'Branch L', ['bark', 'barkdark', 'leaf']),
           11: ('bark', 'Branch R', ['bark', 'barkdark', 'leaf'])},
    groups={0: 'ArmR', 1: 'ArmL', 6: 'LegL', 7: 'LegR', 2: 'Float1', 3: 'Float2', 5: 'Float3', 9: 'Float4'},
    overrides=[dict(shape='sphere', c=(0.0, -0.17, 0.45), r=0.05, label='mint', parts=[8])],
    decals=[],
    glow={},
)

# ----------------------------------------------------------------------------------------------- Pyrion
SPECS['Pyrion'] = dict(
    height=1.2,
    palette={'fur': ('#FFF6E0', 'fur'), 'gold': ('#FDD27A', 'gold'), 'orange': ('#FF9D2E', 'cloth'), 'red': ('#E64B1D', 'cloth'),
             'brown': ('#8B5A2B', 'cloth'), 'dark': ('#3A2A19', 'dark'), 'gem': ('#FF3A1F', 'crystal')},
    parts={0: ('orange', 'Scarf low', ['orange', 'red']), 1: ('orange', 'Scarf', ['orange', 'red']), 2: ('fur', 'Hand R', ['fur', 'gold', 'dark']),
           3: ('orange', 'Scarf end', ['orange', 'red']), 4: ('gold', 'Foot R', ['gold', 'fur', 'dark', 'brown']), 5: ('gold', 'Tail sun', ['gold', 'orange', 'fur']),
           6: ('fur', 'Tail', ['fur', 'orange', 'gold']), 7: ('gold', 'Foot L', ['gold', 'fur', 'dark', 'brown']), 8: ('red', 'Ear L', ['fur', 'orange', 'red', 'gold']),
           9: ('fur', 'Leg L', ['fur', 'gold']), 10: ('gold', 'Belt', ['gold', 'brown']), 11: ('fur', 'Leg R', ['fur', 'gold']),
           12: ('red', 'Ear R', ['fur', 'orange', 'red', 'gold']), 13: ('fur', 'Chest', ['fur', 'orange']), 14: ('fur', 'Head', 'solid'),
           15: ('brown', 'Pouch', ['brown', 'gold']), 16: ('gold', 'Shoulder L', ['gold', 'fur']), 17: ('fur', 'Arm L', ['fur', 'gold']),
           18: ('gold', 'Shoulder R', ['gold', 'fur']), 19: ('gold', 'Forehead', 'solid'), 20: ('orange', 'Collar', ['orange', 'gold', 'red']),
           21: ('fur', 'Arm R', ['fur', 'gold'])},
    groups={0: 'Cape', 1: 'Cape', 3: 'Cape', 2: 'ArmR', 21: 'ArmR', 18: 'ArmR', 4: 'LegR', 11: 'LegR', 7: 'LegL', 5: 'Tail', 6: 'Tail',
            8: 'EarL', 12: 'EarR', 14: 'Head', 19: 'Head', 16: 'ArmL', 17: 'ArmL'},
    overrides=[],
    decals=[dict(kind='anime', part=14, c=(-0.125, 0.539), r=(0.034, 0.026), iris='#F2A53A', tilt=-10),
            dict(kind='anime', part=14, c=(0.011, 0.539), r=(0.034, 0.026), iris='#F2A53A', tilt=10),
            dict(kind='gem', part=19, c=(-0.058, 0.612), r=(0.02, 0.03), color='#FF4A22', front=0.1),
            dict(kind='mouth', part=14, c=(-0.056, 0.505), r=(0.028, 0.01), width=0.25)],
    glow={},
)

# ----------------------------------------------------------------------------------------------- Solmir
SPECS['Solmir'] = dict(
    height=2.0,
    palette={'cream': ('#FBE7C6', 'cloth'), 'gold': ('#F7C453', 'gold'), 'stonelight': ('#EBA329', 'stone'),
             'stone': ('#BB732C', 'stone'), 'stonedark': ('#6B4A2A', 'stone'), 'crystal': ('#FFD45A', 'crystal')},
    parts={0: ('crystal', 'Orb 1', 'solid'), 1: ('crystal', 'Orb 2', 'solid'), 2: ('crystal', 'Orb 3', 'solid'), 3: ('crystal', 'Orb 4', 'solid'),
           4: ('stone', 'Head', ['stonelight', 'stone', 'stonedark', 'gold', 'crystal']), 5: ('stone', 'Fist L', ['stonelight', 'stone', 'stonedark', 'gold']),
           6: ('stone', 'Fist R', ['stonelight', 'stone', 'stonedark', 'gold']), 7: ('cream', 'Tabard', ['cream', 'gold']),
           8: ('stone', 'Foot L', ['stonelight', 'stone', 'stonedark']), 9: ('stone', 'Leg R', ['stonelight', 'stone', 'stonedark', 'gold']),
           10: ('stone', 'Chest', ['stonelight', 'stone', 'stonedark', 'gold', 'cream', 'crystal']), 11: ('stone', 'Leg L', ['stonelight', 'stone', 'stonedark', 'gold']),
           12: ('gold', 'Halo', ['gold', 'crystal']), 13: ('cream', 'Cloth', ['cream', 'gold', 'stone']),
           14: ('stone', 'Pauldron L', ['stonelight', 'stone', 'stonedark', 'gold']), 15: ('stone', 'Hip L', ['stonelight', 'stone', 'stonedark']),
           16: ('gold', 'Belt', ['gold', 'stone'])},
    groups={0: 'Orbit', 1: 'Orbit', 2: 'Orbit', 3: 'Orbit', 4: 'Head', 12: 'Halo', 5: 'ArmL', 14: 'ArmL', 6: 'ArmR', 8: 'LegL', 11: 'LegL', 15: 'LegL', 9: 'LegR'},
    parents={'Halo': 'Head'},
    overrides=[dict(shape='sphere', c=(0.0, -0.15, 0.6), r=0.05, label='crystal', parts=[10])],
    decals=[dict(kind='gem', part=4, c=(0.003, 0.787), r=(0.016, 0.024), color='#FFB43D')],
    glow={0: '#FFC83D', 1: '#FF9A2E', 2: '#FFD45A', 3: '#FFB13D'},
)

# ----------------------------------------------------------------------------------------------- Zahir
SPECS['Zahir'] = dict(
    height=1.8,
    palette={'cream': ('#E8D3A7', 'cloth'), 'gold': ('#D4A85B', 'gold'), 'red': ('#C84B3B', 'cloth'), 'darkred': ('#8A2F2F', 'cloth'),
             'teal': ('#2F6E7A', 'cloth'), 'black': ('#1F1F1F', 'dark'), 'crystal': ('#FF8A2E', 'crystal')},
    parts={0: ('crystal', 'Blade R', 'solid'), 1: ('crystal', 'Blade L', 'solid'), 2: ('gold', 'Back ornament', ['gold', 'crystal']),
           3: ('black', 'Foot L', ['black', 'gold', 'cream']), 4: ('cream', 'Robe', ['cream', 'red', 'darkred', 'teal', 'gold', 'black']),
           5: ('black', 'Hand R', ['black', 'gold']), 6: ('cream', 'Sleeve R', ['cream', 'gold', 'black']), 7: ('black', 'Legs', ['black', 'darkred', 'red', 'gold']),
           8: ('red', 'Scarf', ['red', 'darkred', 'cream', 'teal']), 9: ('black', 'Leg R', ['black', 'gold', 'cream']), 10: ('crystal', 'Chest gem', 'solid'),
           11: ('gold', 'Arm L', ['gold', 'black', 'cream']), 12: ('cream', 'Hood', ['cream', 'black', 'red']), 13: ('teal', 'Shawl', ['teal', 'cream', 'red', 'darkred']),
           14: ('teal', 'Scarf 2', ['teal', 'cream', 'red']), 15: ('gold', 'Halo', ['gold', 'crystal']), 16: ('crystal', 'Hood gem', ['crystal', 'gold']),
           17: ('gold', 'Shoulder R', ['gold', 'black', 'teal']), 18: ('gold', 'Belt', ['gold', 'red', 'black']), 19: ('black', 'Veil', 'solid'),
           20: ('gold', 'Chest armor', ['gold', 'black', 'darkred']), 21: ('darkred', 'Belt R', ['darkred', 'gold', 'black'])},
    groups={12: 'Head', 16: 'Head', 19: 'Head', 15: 'Halo', 5: 'ArmR', 6: 'ArmR', 17: 'ArmR', 0: 'WeaponR', 11: 'ArmL', 1: 'WeaponL',
            3: 'LegL', 9: 'LegR', 8: 'Cape', 14: 'Cape'},
    parents={'Halo': 'Head', 'WeaponR': 'ArmR', 'WeaponL': 'ArmL'},
    overrides=[],
    decals=[dict(kind='glow', part=19, c=(-0.036, 0.676), r=(0.011, 0.006), color='#FFB347', front=0.0),
            dict(kind='glow', part=19, c=(0.014, 0.676), r=(0.011, 0.006), color='#FFB347', front=0.0)],
    glow={0: '#FFB347', 1: '#FF7A2E', 10: '#FF8A2E'},
)

# ----------------------------------------------------------------------------------------------- Solara
SPECS['Solara'] = dict(
    height=2.2,
    palette={'cream': ('#F8E8C7', 'cloth'), 'gold': ('#D4B06A', 'gold'), 'darkgold': ('#C9983C', 'gold'), 'blue': ('#2E7DCB', 'cloth'),
             'water': ('#6ED6F4', 'water'), 'white': ('#FFFFFF', 'cloth'), 'skin': ('#6B4E3A', 'skin')},
    parts={0: ('water', 'Orb', 'solid'), 1: ('gold', 'Hand R', ['gold', 'cream', 'skin']), 2: ('gold', 'Foot back', ['gold', 'cream']),
           3: ('gold', 'Foot R', ['gold', 'cream']), 4: ('gold', 'Staff', ['gold', 'darkgold', 'water']), 5: ('cream', 'Arm L', ['cream', 'gold', 'skin', 'blue']),
           6: ('gold', 'Chest jewel', ['gold', 'water', 'white']), 7: ('cream', 'Robe', ['cream', 'blue', 'water', 'gold', 'white']),
           8: ('gold', 'Halo', ['gold', 'darkgold', 'water']), 9: ('blue', 'Veil R', ['blue', 'water', 'cream']), 10: ('cream', 'Mantle', ['cream', 'white', 'gold', 'blue']),
           11: ('water', 'Back crystal', 'solid'), 12: ('cream', 'Legs', ['cream', 'gold', 'skin']), 13: ('gold', 'Mask', ['gold', 'darkgold', 'water', 'skin']),
           14: ('cream', 'Bust', ['cream', 'gold', 'water']), 15: ('cream', 'Sleeve R', ['cream', 'blue', 'gold']), 16: ('blue', 'Veil L', ['blue', 'water', 'cream']),
           17: ('blue', 'Veil L2', ['blue', 'water', 'cream']), 18: ('gold', 'Back gold', ['gold', 'darkgold']), 19: ('blue', 'Veil R2', ['blue', 'water', 'cream']),
           20: ('blue', 'Ribbon', ['blue', 'water'])},
    groups={13: 'Head', 8: 'Halo', 1: 'ArmR', 15: 'ArmR', 5: 'ArmL', 4: 'Weapon', 0: 'Weapon', 3: 'LegR', 9: 'Cape', 16: 'Cape', 17: 'Cape', 19: 'Cape', 20: 'Cape'},
    parents={'Halo': 'Head', 'Weapon': 'ArmL'},
    overrides=[],
    decals=[dict(kind='gem', part=13, c=(-0.022, 0.70), r=(0.012, 0.02), color='#4FC3F7')],
    glow={0: '#7FE3FF', 11: '#6ED6F4'},
)

# ----------------------------------------------------------------------------------------------- Rajin
SPECS['Rajin'] = dict(
    height=3.0,
    palette={'dark': ('#2B1B16', 'stone'), 'brown': ('#6B4A32', 'stone'), 'bone': ('#D9D0C3', 'stone'), 'red': ('#E74C3C', 'cloth'),
             'orange': ('#FFB347', 'crystal'), 'gold': ('#D8A85A', 'gold'), 'crystal': ('#FF3B2E', 'crystal')},
    parts={0: ('gold', 'Crown', ['gold', 'bone', 'dark']), 1: ('red', 'Scarf front', ['red', 'gold']), 2: ('dark', 'Foot R', ['dark', 'brown', 'bone', 'gold']),
           3: ('dark', 'Foot L', ['dark', 'brown', 'bone', 'gold']), 4: ('dark', 'Leg R', ['dark', 'brown', 'bone', 'gold', 'crystal']),
           5: ('dark', 'Leg L', ['dark', 'brown', 'bone', 'gold', 'crystal']), 6: ('bone', 'Horn', ['bone', 'gold']), 7: ('dark', 'Hand L back', ['dark', 'gold', 'bone']),
           8: ('dark', 'Forearm R', ['dark', 'gold', 'bone', 'red']), 9: ('gold', 'Belt', ['gold', 'red']), 10: ('crystal', 'Chest crystal', 'solid'),
           11: ('bone', 'Skirt', ['bone', 'gold', 'red', 'dark', 'brown']), 12: ('dark', 'Fist L', ['dark', 'gold', 'bone']), 13: ('dark', 'Fist R', ['dark', 'gold', 'bone']),
           14: ('dark', 'Arm L', ['dark', 'gold', 'bone', 'red']), 15: ('dark', 'Armor+cape', ['dark', 'brown', 'bone', 'red', 'gold', 'crystal']),
           16: ('dark', 'Waist', ['dark', 'brown', 'gold', 'red'])},
    groups={7: 'ArmL', 12: 'ArmL', 14: 'ArmL', 8: 'ArmR', 13: 'ArmR', 2: 'LegR', 4: 'LegR', 3: 'LegL', 5: 'LegL'},
    overrides=[],
    decals=[],
    glow={10: '#FF4A3A'},
)

# ----------------------------------------------------------------------------------------------- Helius
SPECS['Helius'] = dict(
    height=4.0,
    palette={'cream': ('#FFF5E1', 'cloth'), 'gold': ('#D4B27A', 'gold'), 'bronze': ('#8C6A3B', 'gold'), 'navy': ('#1F2B4D', 'cloth'),
             'black': ('#0E1321', 'dark'), 'sun': ('#FAD246', 'crystal')},
    parts={0: ('gold', 'Rings', ['gold', 'bronze', 'sun']), 1: ('cream', 'Hood', ['cream', 'black', 'gold', 'navy']), 2: ('bronze', 'Foot L', ['bronze', 'gold', 'black']),
           3: ('bronze', 'Foot R', ['bronze', 'gold', 'black']), 4: ('sun', 'Crescent', 'solid'), 5: ('cream', 'Robe', ['cream', 'navy', 'gold', 'bronze', 'black']),
           6: ('cream', 'Scarf', ['cream', 'navy', 'gold']), 7: ('bronze', 'Hand R', ['bronze', 'gold', 'black']), 8: ('navy', 'Robe front', ['navy', 'cream', 'gold']),
           9: ('gold', 'Staff', ['gold', 'bronze', 'sun']), 10: ('cream', 'Scarf 2', ['cream', 'navy', 'gold']), 11: ('bronze', 'Hand L', ['bronze', 'gold', 'black']),
           12: ('navy', 'Legs', ['navy', 'black', 'gold']), 13: ('gold', 'Belt', ['gold', 'bronze', 'sun']), 14: ('cream', 'Scarf 3', ['cream', 'navy', 'gold'])},
    groups={0: 'Halo', 1: 'Head', 4: 'Orbit', 7: 'ArmR', 11: 'ArmL', 9: 'Weapon', 2: 'LegL', 3: 'LegR', 6: 'Cape', 10: 'Cape', 14: 'Cape'},
    parents={'Halo': 'Head', 'Weapon': 'ArmL'},
    # visage sombre sous la capuche (planche) : trop petit pour survivre au nettoyage des îlots
    overrides=[dict(shape='ellipsoid', c=(-0.012, -0.16, 0.77), r=(0.04, 0.05, 0.05), label='black', parts=[1], front=0.25)],
    decals=[dict(kind='glow', part=1, c=(0.007, 0.772), r=(0.013, 0.013), color='#FAD246', front=0.2)],
    glow={4: '#FAD246'},
)

# =============================================================================================== tuning pass
def _p(h, i, default, allowed):
    name = SPECS[h]['parts'][i][1]
    SPECS[h]['parts'][i] = (default, name, allowed)

# Cylla : cheveux verts, fleurs roses dans la couronne, jupe de feuilles et pétales.
_p('Cylla', 0, 'hair', ['hairdark', 'hair', 'pink', 'petal'])
_p('Cylla', 1, 'hairdark', ['hairdark', 'hair']); _p('Cylla', 2, 'hairdark', ['hairdark', 'hair'])
_p('Cylla', 3, 'hair', ['hairdark', 'hair', 'petal', 'leaf'])
_p('Cylla', 10, 'hair', ['hair', 'hairdark', 'petal']); _p('Cylla', 11, 'hair', ['hair', 'hairdark', 'petal'])
_p('Cylla', 13, 'hair', ['hair', 'hairdark', 'leaf'])
_p('Cylla', 5, 'skin', 'solid'); _p('Cylla', 7, 'skin', 'solid'); _p('Cylla', 8, 'skin', 'solid')
SPECS['Cylla']['overrides'] = [
    dict(shape='z', z=(0.84, 1.2), label='pink', parts=[0], noise=(18, 0.62), seed=5),
    dict(shape='z', z=(0.84, 1.2), label='petal', parts=[0], noise=(18, 0.66), seed=9),
    dict(shape='z', z=(0.84, 1.2), label='wood', parts=[0], noise=(30, 0.70), seed=21),
    dict(shape='z', z=(0.0, 0.30), label='petal', parts=[3], noise=(10, 0.55), seed=3),
]

# Lumora : cheveux crème, couronne dorée, ailes de cristal jaune.
_p('Lumora', 6, 'cream', ['cream', 'light'])
for i in (0, 1, 2, 3, 7, 8):
    _p('Lumora', i, 'yellow', 'solid')
_p('Lumora', 15, 'cream', ['cream', 'light', 'leaf']); _p('Lumora', 4, 'cream', ['cream', 'light']); _p('Lumora', 12, 'cream', ['cream', 'light'])
_p('Lumora', 17, 'leafdark', ['leafdark', 'leaf', 'gold']); _p('Lumora', 14, 'light', ['light', 'cream'])
_p('Lumora', 5, 'leafdark', ['leafdark', 'skin', 'gold']); _p('Lumora', 11, 'leafdark', ['leafdark', 'skin', 'gold'])
SPECS['Lumora']['overrides'] = [
    dict(shape='z', z=(0.80, 1.2), label='gold', parts=[6], noise=(16, 0.6), seed=4),
    dict(shape='sphere', c=(0.0, -0.17, 0.43), r=0.03, label='yellow', parts=[17, 14]),
    dict(shape='z', z=(0.0, 0.35), label='leaf', parts=[15], noise=(9, 0.62), seed=8),
]

# Pyrion : fourrure crème propre, oreilles rouge-orange.
for i in (2, 9, 11, 13, 17, 21):
    _p('Pyrion', i, 'fur', 'solid')
_p('Pyrion', 6, 'fur', 'solid')
_p('Pyrion', 8, 'red', ['fur', 'red', 'orange']); _p('Pyrion', 12, 'red', ['fur', 'red', 'orange'])

# Thornix : feuillage dense sur les épaules, fleurs rouges, masque blanc, bois aux pointes rougeoyantes.
SPECS['Thornix']['overrides'] = [
    dict(shape='z', z=(0.80, 2.0), label='bark', parts=[1], **{'from': ['mask', 'leaf', 'leafdark']}),
    dict(shape='z', z=(0.90, 2.0), label='barkdark', parts=[1], noise=(14, 0.55), seed=2),
    dict(shape='z', z=(0.93, 2.0), label='red', parts=[1], noise=(20, 0.6), seed=6),
    dict(shape='z', z=(0.52, 0.80), label='leaf', parts=[1], absx=(0.11, 1.0)),
    dict(shape='z', z=(0.52, 0.80), label='leafdark', parts=[1], absx=(0.11, 1.0), noise=(16, 0.55), seed=12),
    dict(shape='z', z=(0.52, 0.80), label='red', parts=[1], absx=(0.11, 1.0), noise=(26, 0.72), seed=13),
    dict(shape='z', z=(0.60, 0.80), label='mask', parts=[1], absx=(0.0, 0.10), front=0.2),
    dict(shape='sphere', c=(0.0, -0.18, 0.56), r=0.06, label='red', parts=[1]),
    dict(shape='z', z=(0.40, 0.50), label='leaf', parts=[5, 7]),
    dict(shape='all', label='leaf', parts=[0, 2, 3, 4, 5, 7], noise=(12, 0.66), seed=17),
    dict(shape='all', label='red', parts=[0, 2, 3, 4, 5, 7], noise=(30, 0.74), seed=19),
]

# Verdantis : feuillage vert dominant, bois, masque crème, cristal central menthe, fleurs roses.
SPECS['Verdantis']['overrides'] = [
    dict(shape='all', label='leaf', parts=[4]),
    dict(shape='all', label='leafdark', parts=[4], noise=(12, 0.52), seed=3),
    dict(shape='all', label='pink', parts=[4], noise=(24, 0.70), seed=5),
    dict(shape='z', z=(0.72, 0.88), label='cream', parts=[4], absx=(0.0, 0.07), front=0.3),
    dict(shape='all', label='bark', parts=[10, 11]),
    dict(shape='all', label='bark', parts=[2, 3, 5, 9]),
    dict(shape='z', z=(0.66, 2.0), label='leaf', parts=[2, 9]),
    dict(shape='z', z=(0.64, 2.0), label='leaf', parts=[3, 5]),
    dict(shape='all', label='pink', parts=[2, 3, 5, 9], noise=(26, 0.68), seed=7),
    dict(shape='all', label='bark', parts=[0, 1, 6, 7, 8]),
    dict(shape='all', label='barkdark', parts=[0, 1, 6, 7, 8], noise=(10, 0.6), seed=9),
    dict(shape='all', label='leaf', parts=[0, 1, 6, 7, 8], noise=(9, 0.6), seed=23),
    dict(shape='z', z=(0.52, 0.62), label='leaf', parts=[8]),
    dict(shape='all', label='pink', parts=[0, 1, 6, 7, 8], noise=(28, 0.75), seed=29),
    dict(shape='sphere', c=(0.0, -0.17, 0.45), r=0.05, label='mint', parts=[8]),
]
SPECS['Verdantis']['project'] = False

# ---- tuning pass 2
_p('Cylla', 0, 'hair', ['hairdark', 'hair'])
_p('Pyrion', 4, 'gold', ['gold', 'brown']); _p('Pyrion', 7, 'gold', ['gold', 'brown'])
_p('Pyrion', 16, 'gold', 'solid'); _p('Pyrion', 18, 'gold', 'solid'); _p('Pyrion', 10, 'gold', ['gold', 'brown'])
SPECS['Thornix']['overrides'] = [
    dict(shape='z', z=(0.80, 2.0), label='bark', parts=[1], **{'from': ['mask', 'leaf', 'leafdark']}),
    dict(shape='z', z=(0.90, 2.0), label='barkdark', parts=[1], noise=(14, 0.55), seed=2),
    dict(shape='z', z=(0.93, 2.0), label='red', parts=[1], noise=(20, 0.6), seed=6),
    dict(shape='z', z=(0.56, 0.78), label='leaf', parts=[1]),
    dict(shape='z', z=(0.47, 0.86), label='leaf', parts=[1], noise=(10, 0.47), seed=31),
    dict(shape='z', z=(0.47, 0.86), label='leafdark', parts=[1], noise=(16, 0.55), seed=12),
    dict(shape='z', z=(0.47, 0.86), label='red', parts=[1], noise=(26, 0.72), seed=13),
    dict(shape='ellipsoid', c=(0.0, -0.16, 0.70), r=(0.075, 0.12, 0.085), label='mask', parts=[1], front=0.15),
    dict(shape='sphere', c=(0.0, -0.18, 0.56), r=0.055, label='red', parts=[1]),
    dict(shape='z', z=(0.40, 0.50), label='leaf', parts=[5, 7]),
    dict(shape='all', label='leaf', parts=[0, 2, 3, 4, 5, 7], noise=(12, 0.66), seed=17),
    dict(shape='all', label='red', parts=[0, 2, 3, 4, 5, 7], noise=(30, 0.74), seed=19),
]
