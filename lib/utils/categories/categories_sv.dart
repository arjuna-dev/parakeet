const categories = [
  {
    "name": "At the Coffee Shop",
    "words": ["kaffe", "te", "mjölk", "socker", "kopp", "beställning", "meny", "bord", "barista", "kvitto", "växel", "ta med", "is", "varm", "sked", "servett", "grädde", "espresso", "latte", "dricks"]
  },
  {
    "name": "Weather Talk",
    "words": ["soligt", "regnigt", "molnigt", "blåsigt", "stormigt", "snö", "varmt", "kallt", "ljummet", "friskt", "väderprognos", "paraply", "jacka", "temperatur", "grader", "årstid", "fuktigt", "torrt"]
  },
  {
    "name": "In the Supermarket",
    "words": ["kundvagn", "korg", "gång", "kassa", "kassör", "kvitto", "påse", "frukt", "grönsaker", "bröd", "mejeriprodukter", "kött", "fryst", "konserver", "hylla", "pris", "rea", "streckkod", "kontanter", "kort"]
  },
  {
    "name": "Asking for Directions",
    "words": ["karta", "gata", "väg", "aveny", "vänster", "höger", "rakt fram", "hörn", "kvarter", "trafikljus", "korsning", "svänga", "nära", "långt", "bakom", "framför", "bredvid", "mellan", "mittemot", "skylt"]
  },
  {
    "name": "Making Small Talk",
    "words": ["hej", "hallå", "hur mår du", "bra", "tack", "du", "väder", "bra", "dåligt", "upptagen", "trött", "helg", "planer", "njuta", "idag", "imorgon", "igår", "trevligt", "träffa", "igen"]
  },
  {
    "name": "At the Airport",
    "words": [
      "boardingkort",
      "pass",
      "bagage",
      "incheckning",
      "säkerhetskontroll",
      "gate",
      "flyg",
      "försening",
      "avgång",
      "ankomst",
      "terminal",
      "bagageutlämning",
      "tull",
      "biljett",
      "plats",
      "ombordstigning",
      "handbagage",
      "barnvagn",
      "visum",
      "taxfree"
    ]
  },
  {
    "name": "At the Restaurant",
    "words": ["meny", "servitör", "bokning", "beställning", "förrätt", "huvudrätt", "dessert", "nota", "dricks", "dryck", "vatten", "vin", "öl", "gaffel", "kniv", "sked", "tallrik", "glas", "servett", "specialitet"]
  },
  {
    "name": "At the Hotel",
    "words": [
      "reception",
      "incheckning",
      "utcheckning",
      "rum",
      "nyckel",
      "bokning",
      "bagage",
      "hiss",
      "frukost",
      "wi-fi",
      "dusch",
      "handduk",
      "säng",
      "kudde",
      "täcke",
      "luftkonditionering",
      "tvätt",
      "service",
      "kassaskåp",
      "utsikt"
    ]
  },
  {
    "name": "At the Doctor's Office",
    "words": [
      "tid",
      "läkare",
      "sjuksköterska",
      "symtom",
      "smärta",
      "feber",
      "hosta",
      "huvudvärk",
      "recept",
      "medicin",
      "apotek",
      "allergi",
      "blodtryck",
      "temperatur",
      "stetoskop",
      "bandage",
      "spruta",
      "röntgen",
      "diagnos",
      "behandling"
    ]
  },
  {
    "name": "Public Transportation",
    "words": [
      "buss",
      "tåg",
      "tunnelbana",
      "biljett",
      "station",
      "hållplats",
      "tidtabell",
      "karta",
      "linje",
      "plattform",
      "avgift",
      "byte",
      "passagerare",
      "förare",
      "konduktör",
      "försening",
      "utgång",
      "ingång",
      "sittplats",
      "stående"
    ]
  },
  {
    "name": "Shopping for Clothes",
    "words": ["skjorta", "byxor", "klänning", "skor", "storlek", "färg", "pris", "rea", "provrum", "kassör", "kvitto", "påse", "jacka", "tröja", "kjol", "hatt", "strumpor", "jeans", "bälte", "rabatt"]
  },
  {
    "name": "At the Gym",
    "words": [
      "löpband",
      "vikter",
      "yoga",
      "stretching",
      "tränare",
      "medlemskap",
      "skåp",
      "dusch",
      "handduk",
      "vattenflaska",
      "träning",
      "kondition",
      "styrka",
      "repetitioner",
      "set",
      "uppvärmning",
      "nedvarvning",
      "hantlar",
      "skivstång",
      "maskin"
    ]
  },
  {
    "name": "At the Bank",
    "words": [
      "konto",
      "uttag",
      "insättning",
      "lån",
      "ränta",
      "kreditkort",
      "betalkort",
      "bankomat",
      "banktjänsteman",
      "saldo",
      "valuta",
      "växling",
      "check",
      "sparande",
      "investering",
      "lösenord",
      "pinkod",
      "utdrag",
      "avgift",
      "överföring"
    ]
  },
  {
    "name": "At the Post Office",
    "words": [
      "paket",
      "brev",
      "frimärke",
      "kuvert",
      "adress",
      "vykort",
      "paket",
      "leverans",
      "spårning",
      "brevlåda",
      "avsändare",
      "mottagare",
      "vikt",
      "storlek",
      "prioritet",
      "express",
      "luftpost",
      "tull",
      "avgift",
      "kvitto"
    ]
  },
  {
    "name": "At the Pharmacy",
    "words": [
      "medicin",
      "recept",
      "smärtstillande",
      "bandage",
      "vitaminer",
      "hostmedicin",
      "allergi",
      "kräm",
      "salva",
      "tablett",
      "tablett",
      "kapsel",
      "apotekare",
      "dosering",
      "biverkningar",
      "påfyllning",
      "antibiotika",
      "termometer",
      "mask",
      "desinfektionsmedel"
    ]
  },
  {
    "name": "At the Park",
    "words": ["bänk", "träd", "gräs", "stig", "lekplats", "fontän", "hund", "picknick", "cykel", "jogging", "blommor", "damm", "anka", "skugga", "sol", "barn", "gunga", "rutschkana", "papperskorg", "staty"]
  },
  {
    "name": "At the Beach",
    "words": ["sand", "vågor", "sol", "parasoll", "handduk", "baddräkt", "solkräm", "solglasögon", "hatt", "snäckor", "mås", "hav", "tidvatten", "surfing", "bräda", "snorkling", "mask", "fenor", "strandboll", "glass"]
  },
  {
    "name": "At the Library",
    "words": [
      "bok",
      "hylla",
      "katalog",
      "låna",
      "lämna tillbaka",
      "förfallodatum",
      "bibliotekarie",
      "studera",
      "tyst",
      "skrivbord",
      "stol",
      "dator",
      "internet",
      "tidskrift",
      "tidning",
      "fiktion",
      "facklitteratur",
      "referens",
      "lån",
      "kort"
    ]
  },
  {
    "name": "At the Cinema",
    "words": [
      "biljett",
      "film",
      "popcorn",
      "dryck",
      "plats",
      "duk",
      "trailer",
      "genre",
      "skräck",
      "komedi",
      "action",
      "drama",
      "romantik",
      "regissör",
      "skådespelare",
      "skådespelerska",
      "undertexter",
      "3d",
      "visningstid",
      "godis"
    ]
  },
  {
    "name": "At the Hair Salon",
    "words": ["hårklippning", "schampo", "balsam", "frisör", "sax", "kam", "hårtork", "färg", "slingor", "trimma", "lugg", "lockar", "plattång", "tid", "spegel", "stol", "kappa", "rakhyvel", "gelé", "spray"]
  }
];
