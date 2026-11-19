// Synthetic-but-realistic data generator used by the seed script and the matching evaluation.
// Everything is driven by a seeded RNG, so `npm run db:seed` is reproducible.

export function rng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const r = {
    next,
    chance: (p) => next() < p,
    int: (lo, hi) => lo + Math.floor(next() * (hi - lo + 1)),
    float: (lo, hi) => lo + next() * (hi - lo),
    pick: (arr) => arr[Math.floor(next() * arr.length)],
    sample: (arr, n) => {
      const c = [...arr];
      const out = [];
      while (out.length < n && c.length) out.push(c.splice(Math.floor(next() * c.length), 1)[0]);
      return out;
    },
  };
  return r;
}

export const FIRST = ['Aarav', 'Vivaan', 'Aditya', 'Arjun', 'Rohan', 'Karthik', 'Rahul', 'Siddharth', 'Nikhil', 'Varun', 'Harsh', 'Manoj',
  'Ananya', 'Diya', 'Isha', 'Meera', 'Priya', 'Sneha', 'Kavya', 'Divya', 'Pooja', 'Riya', 'Shruti', 'Neha', 'Bindu', 'Lakshmi', 'Deepa', 'Anjali'];
export const LAST = ['Sharma', 'Reddy', 'Nair', 'Iyer', 'Gowda', 'Rao', 'Patel', 'Menon', 'Kulkarni', 'Hegde', 'Shetty', 'Bhat',
  'Kumar', 'Singh', 'Das', 'Joshi', 'Pillai', 'Naik'];

const cap = (s) => (s ? s[0].toUpperCase() + s.slice(1) : s);
const list = (arr) => (arr.length <= 1 ? arr.join('') : `${arr.slice(0, -1).join(', ')} and ${arr[arr.length - 1]}`);

// [found-phrasing, owner-phrasing] pairs describe the same physical feature in different words.
export const CATALOG = {
  Phone: {
    nouns: [['smartphone', ['mobile', 'cellphone', 'phone']], ['mobile phone', ['handset', 'phone', 'mobile']], ['phone', ['cellphone', 'mobile']]],
    brands: ['Samsung', 'Apple', 'OnePlus', 'Xiaomi', 'Realme', 'Vivo', 'Oppo', 'Google'],
    colors: ['black', 'white', 'blue', 'silver', 'gray', 'green', 'red', 'gold'],
    features: [['a cracked screen guard', 'the tempered glass on the screen is broken'], ['a transparent silicone back cover', 'a clear rubber cover'],
      ['a small cartoon sticker on the back', 'a sticker stuck behind it'], ['a pop socket grip', 'a finger holder grip at the back'],
      ['a dent on the top-right corner', 'one corner is dented'], ['a card pocket on the case', 'a flip case with space for cards'],
      ['a lanyard strap attached', 'a neck strap tied to it']],
    hints: [['What photo is on the lock screen?', ['mountain', 'beach', 'dog', 'sunset', 'family', 'car']],
      ['Which app is first in the bottom dock?', ['whatsapp', 'camera', 'phone', 'chrome']]],
  },
  Wallet: {
    nouns: [['wallet', ['wallet', 'billfold']], ['leather wallet', ['wallet', 'purse']], ['purse', ['purse', 'wallet']]],
    brands: ['Wildcraft', 'Fastrack', 'Tommy Hilfiger', 'Puma', 'Hidesign', 'Woodland'],
    colors: ['brown', 'black', 'tan', 'blue', 'red'],
    features: [['several cards and some cash inside', 'a few bank cards and notes in it'], ['a zip coin pocket', 'a coin pouch with a zip'],
      ['initials embossed in a corner', 'my initials printed on it'], ['a faded photo in the transparent slot', 'a small photo in the window slot'],
      ['a worn edge along the fold', 'frayed along the fold'], ['a bus pass tucked in', 'a metro card inside']],
    hints: [['Whose photo is in the front slot?', ['mother', 'wife', 'dog', 'girlfriend', 'myself']],
      ['Roughly how much cash is inside?', ['500', '1000', '200', '1500', '50']]],
  },
  Bag: {
    nouns: [['backpack', ['rucksack', 'bag', 'backpack']], ['laptop bag', ['bag', 'satchel']], ['handbag', ['handbag', 'bag']], ['sling bag', ['sling', 'bag']], ['duffel bag', ['gym bag', 'bag']]],
    brands: ['Skybags', 'American Tourister', 'Wildcraft', 'Puma', 'Nike', 'Adidas', 'Safari'],
    colors: ['black', 'blue', 'gray', 'red', 'green', 'navy', 'brown'],
    features: [['a small teddy keychain', 'a teddy bear hanging from the zip'], ['notebooks and a pencil box inside', 'books and stationery in it'],
      ['a damaged front pocket zip', 'the front pocket zipper is broken'], ['a name tag with faded ink', 'a worn-out name label'],
      ['reflective strips on the straps', 'shiny strips on the shoulder straps'], ['a side pocket for a bottle', 'a side holder for a water bottle']],
    hints: [['What colour is the pencil box inside?', ['red', 'blue', 'green', 'pink']], ['Which book is on top?', ['physics', 'dbms', 'calculus', 'novel', 'maths']]],
  },
  Keys: {
    nouns: [['bunch of keys', ['keys', 'key bunch']], ['key set', ['keys', 'keychain']], ['car key', ['car key', 'key']], ['bike key', ['bike key', 'key']]],
    brands: ['Honda', 'Hyundai', 'Maruti', 'Bajaj', 'Yamaha', 'Godrej'],
    colors: ['silver', 'black', 'gold', 'red'],
    features: [['a red leather keychain', 'a red fob'], ['a tiny bottle opener charm', 'a small opener attached'], ['three keys and a remote', 'three keys plus a remote'],
      ['a plastic tag with a room number', 'a tag showing my room number'], ['a metal ring with a heart charm', 'a heart shaped charm']],
    hints: [['What is written on the tag?', ['204', '12b', '7', '312', 'a3']], ['What charm is on the ring?', ['heart', 'star', 'bottle opener', 'football']]],
  },
  Laptop: {
    nouns: [['laptop', ['laptop', 'notebook']], ['notebook computer', ['notebook', 'laptop']], ['ultrabook', ['laptop', 'macbook']]],
    brands: ['Dell', 'HP', 'Lenovo', 'Apple', 'Asus', 'Acer'],
    colors: ['silver', 'black', 'gray'],
    features: [['stickers of programming languages on the lid', 'coding stickers on the cover'], ['a scratch near the trackpad', 'scratched around the touchpad'],
      ['a padded sleeve with a zip', 'a laptop sleeve'], ['a charger wrapped in a rubber band', 'the charger tied up with a band'],
      ['a dent on the left corner', 'the left corner is dented'], ['a sliding webcam cover', 'a webcam shutter']],
    hints: [['What sticker is on the lid?', ['python', 'linux', 'github', 'docker', 'react']], ['What is the desktop wallpaper?', ['mountain', 'anime', 'car', 'abstract', 'space']]],
  },
  Earphones: {
    nouns: [['wireless earbuds', ['earbuds', 'airpods', 'earphones']], ['earphones', ['earphones', 'headset']], ['headphones', ['headset', 'headphones']], ['charging case with earbuds', ['earbuds', 'case']]],
    brands: ['boAt', 'Sony', 'JBL', 'Apple', 'Samsung', 'Realme', 'OnePlus'],
    colors: ['black', 'white', 'blue', 'pink', 'red'],
    features: [['a scratched charging case', 'the case is scratched'], ['a knotted wire', 'the wire is tangled'], ['a pink silicone cover', 'a pink rubber case'],
      ['a missing ear tip', 'one tip is gone'], ['a neckband style', 'it is the neckband type']],
    hints: [['What colour is the case?', ['black', 'white', 'pink', 'blue']], ['Which side has a scratch?', ['left', 'right']]],
  },
  'ID / Cards': {
    nouns: [['student ID card', ['id card', 'identity card']], ['debit card', ['bank card', 'debit card']], ['driving licence', ['licence', 'driving license']], ['library card', ['library card', 'id']]],
    brands: [],
    colors: ['blue', 'white', 'green'],
    features: [['a blue lanyard', 'a blue neck strap'], ['a laminated cover', 'plastic laminated'], ['a plastic holder with a clip', 'a clip holder'], ['a small passport photo', 'my photo on the front']],
    hints: [['What is the birth year on it?', ['2002', '2003', '2001', '1999', '2000']], ['What is the first name on it?', ['arjun', 'meera', 'rohan', 'diya', 'karthik']]],
  },
  Clothing: {
    nouns: [['hoodie', ['hoodie', 'sweatshirt']], ['jacket', ['jacket', 'coat']], ['sweater', ['sweater', 'pullover']], ['scarf', ['scarf', 'muffler']], ['cap', ['cap', 'hat']]],
    brands: ['H&M', 'Nike', 'Adidas', 'Zara', 'Roadster', 'Puma', 'Levis'],
    colors: ['black', 'navy', 'gray', 'maroon', 'olive', 'white'],
    features: [['a university logo on the chest', 'the college logo printed on it'], ['a stuck zip', 'the zipper is jammed'], ['a stain on one sleeve', 'a mark on the sleeve'],
      ['a size M tag', 'a medium size label'], ['tissues in the pocket', 'some tissues left inside the pocket'], ['fleece lining', 'woolly fur inside']],
    hints: [['What is in the left pocket?', ['tissues', 'earphones', 'key', 'coins']], ['What size is on the tag?', ['s', 'm', 'l', 'xl']]],
  },
  'Watch / Jewellery': {
    nouns: [['wrist watch', ['watch', 'wristwatch']], ['smartwatch', ['smartwatch', 'watch']], ['silver ring', ['ring']], ['gold chain', ['chain', 'necklace']], ['bracelet', ['bracelet', 'band']]],
    brands: ['Fossil', 'Titan', 'Casio', 'Apple', 'Noise', 'Fastrack', 'Tanishq'],
    colors: ['silver', 'gold', 'black', 'brown'],
    features: [['a cracked glass', 'a scratched dial'], ['a leather strap with worn holes', 'a brown strap that is worn out'], ['an engraved initial on the back', 'a letter carved behind'],
      ['a missing link', 'one link is absent'], ['a blue dial', 'the dial is blue']],
    hints: [['What is engraved on it?', ['ak', 'rs', 'mv', 'sp', 'love']], ['What colour is the dial or stone?', ['blue', 'black', 'white', 'green']]],
  },
  'Water Bottle': {
    nouns: [['water bottle', ['bottle', 'water bottle']], ['steel flask', ['flask', 'bottle']], ['sipper', ['sipper', 'bottle']], ['thermos', ['thermos', 'flask']]],
    brands: ['Milton', 'Cello', 'Borosil', 'Tupperware', 'Hydro Flask', 'Nike'],
    colors: ['blue', 'black', 'steel', 'green', 'pink', 'orange'],
    features: [['a dented bottom', 'a dent at the base'], ['a few stickers on the side', 'some stickers on the body'], ['a flip-top lid', 'a sports cap lid'],
      ['a name written in marker', 'my name in marker pen'], ['a rope loop on the cap', 'a rope handle on the lid']],
    hints: [['What sticker is on it?', ['football', 'cartoon', 'flag', 'anime']], ['What name is written on it?', ['rahul', 'meera', 'priya', 'arjun']]],
  },
  Umbrella: {
    nouns: [['umbrella', ['umbrella', 'brolly']], ['folding umbrella', ['folding umbrella', 'umbrella']], ['long umbrella', ['umbrella', 'brolly']]],
    brands: ['Fastrack', 'Popy', 'Amazon Basics', 'Rain Mate'],
    colors: ['black', 'blue', 'red', 'green', 'yellow'],
    features: [['a wooden curved handle', 'a wooden hook handle'], ['one bent rib', 'a broken spoke'], ['a printed floral pattern', 'flowers printed on it'],
      ['a velcro strap', 'a velcro tie'], ['an automatic open button', 'a push button to open']],
    hints: [['What is the handle made of?', ['wood', 'plastic', 'metal']], ['Is there a strap or a cover?', ['strap', 'cover', 'neither']]],
  },
  Spectacles: {
    nouns: [['spectacles', ['specs', 'glasses', 'eyeglasses']], ['sunglasses', ['sunglasses', 'shades']], ['reading glasses', ['reading glasses', 'specs']], ['eyeglasses', ['glasses', 'specs']]],
    brands: ['Ray-Ban', 'Titan Eye+', 'Lenskart', 'Fastrack', 'Oakley'],
    colors: ['black', 'brown', 'gold', 'transparent', 'blue'],
    features: [['a hard case and a cleaning cloth', 'a case with a cloth along with it'], ['a scratched left lens', 'the left glass is scratched'], ['a thin metal frame', 'a wire frame'],
      ['a blue-cut coating', 'anti glare lenses'], ['tape on the hinge', 'the hinge is taped']],
    hints: [['What colour is the case?', ['black', 'brown', 'blue', 'red']], ['Which lens is scratched?', ['left', 'right']]],
  },
  Documents: {
    nouns: [['folder with papers', ['documents', 'files']], ['certificate file', ['certificates', 'documents']], ['passport', ['passport']], ['marksheet folder', ['marksheets', 'papers']]],
    brands: [],
    colors: ['blue', 'black', 'red', 'green', 'transparent'],
    features: [['original marksheets inside', 'semester marksheets in it'], ['a transparent plastic folder', 'a clear plastic file'], ['a rubber band around it', 'a band tied around'],
      ['a resume on top', 'my cv at the front'], ['an admit card', 'a hall ticket']],
    hints: [['Whose name is on the first page?', ['arjun', 'meera', 'rohan', 'diya', 'karthik']], ['What is the first page about?', ['resume', 'marksheet', 'passport', 'invoice']]],
  },
  Other: {
    nouns: [['power bank', ['power bank', 'charger']], ['calculator', ['calculator']], ['pen drive', ['pendrive', 'usb stick']], ['charger', ['charger', 'adapter']], ['lunch box', ['tiffin box', 'lunch box']]],
    brands: ['Mi', 'Casio', 'SanDisk', 'Anker', 'Ambrane', 'Tupperware'],
    colors: ['black', 'white', 'blue', 'red', 'silver'],
    features: [['a label with initials', 'initials on a sticker'], ['a cracked corner', 'one corner is broken'], ['a football club sticker', 'a sticker of a football team'], ['a velcro pouch', 'a small cloth pouch']],
    hints: [['What is written on it?', ['kiran', 'cse', 'room 5', 'mine']], ['What colour is the sticker?', ['red', 'blue', 'green', 'yellow']]],
  },
};

const EXTRA = ['Looks well used.', 'Handed in by a passer-by.', 'Was lying on a seat.', 'Found in the morning.', 'Picked up from the floor.', 'Left unattended.', ''];
const STORAGE = ['Shelf A', 'Shelf B', 'Shelf C', 'Locker 4', 'Locker 9', 'Cabinet 2', 'Reception drawer'];

export function newFoundSpec(r, catName, locations) {
  const cat = CATALOG[catName];
  const [noun, lostNouns] = r.pick(cat.nouns);
  const color = r.chance(0.9) ? r.pick(cat.colors) : null;
  const brand = cat.brands.length && r.chance(0.8) ? r.pick(cat.brands) : null;
  const feats = r.sample(cat.features, r.int(1, 3));
  const loc = r.pick(locations);
  const hintDef = r.chance(0.75) ? r.pick(cat.hints) : null;
  const answer = hintDef ? r.pick(hintDef[1]) : null;
  const title = [cap(color || ''), brand || '', noun].filter(Boolean).join(' ').replace(/\s+/g, ' ').trim();
  const desc = `${cap([color, brand, noun].filter(Boolean).join(' '))} with ${list(feats.map((f) => f[0]))}. Found at ${loc.name}. ${r.pick(EXTRA)}`.trim();
  return {
    catName, noun, lostNouns, color, brand, feats, loc, title, description: desc,
    hint: hintDef ? hintDef[0] : null, answer, hintDef,
    storage: r.pick(STORAGE),
  };
}

/** What the true owner would type into the "I lost something" form. Deliberately paraphrased and incomplete. */
export function lostQueryFor(r, spec, ctx) {
  const { categoriesByName, locations, foundAt } = ctx;
  const n = r.pick(spec.lostNouns);
  const showColor = spec.color && r.chance(0.7);
  const showBrand = spec.brand && r.chance(0.6);
  const feats = r.sample(spec.feats.map((f) => f[1]), r.int(1, Math.min(2, spec.feats.length)));
  const lead = [showColor ? spec.color : '', showBrand ? spec.brand : '', n].filter(Boolean).join(' ');
  const t = r.int(0, 3);
  const locPhrase = r.chance(0.5) ? ` Last seen near ${spec.loc.name}.` : '';
  const description = [
    `I lost my ${lead}. It has ${list(feats)}.${locPhrase}`,
    `Missing: ${lead}. ${cap(list(feats))}.${locPhrase}`,
    `Looking for my ${lead} - ${list(feats)}.${locPhrase}`,
    `Please help, my ${n} is gone. ${cap(list(feats))}.${locPhrase}`,
  ][t];

  let locationId = null;
  const lr = r.next();
  if (lr < 0.7) locationId = spec.loc.location_id;
  else if (lr < 0.9) locationId = r.pick(locations.filter((l) => l.location_id !== spec.loc.location_id)).location_id;

  const lostAt = r.chance(0.85) ? new Date(foundAt.getTime() - r.float(1, 30) * 3600 * 1000).toISOString() : null;
  return {
    description,
    category_id: r.chance(0.9) ? categoriesByName[spec.catName] : null,
    color: showColor && r.chance(0.8) ? spec.color : null,
    brand: showBrand && r.chance(0.8) ? spec.brand : null,
    location_id: locationId,
    lost_at: lostAt,
  };
}

export function ownerClaimText(r, spec) {
  const feats = spec.feats.map((f) => f[1]);
  return `This is my ${r.pick(spec.lostNouns)}${spec.brand ? ` (${spec.brand})` : ''}. It has ${list(feats)}. I lost it ${r.chance(0.5) ? 'a few hours' : 'a day'} before it was reported.`;
}

export function impostorClaimText(r, spec) {
  const f = r.pick(spec.feats)[1];
  return `I think this is my ${r.pick(spec.lostNouns)}. ${cap(f)}. I need it back urgently, please check.`;
}

export function wrongAnswer(r, spec) {
  const pool = spec.hintDef ? spec.hintDef[1].filter((a) => a !== spec.answer) : ['not sure'];
  return pool.length ? r.pick(pool) : 'not sure';
}

export { cap, list };
