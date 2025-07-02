const categories = [
  {
    "name": "At the Coffee Shop",
    "words": ["kaffe", "te", "melk", "sukker", "kopp", "bestilling", "meny", "bord", "barista", "kvittering", "vekslepenger", "takeaway", "is", "varm", "skje", "serviett", "fløte", "espresso", "latte", "tips"]
  },
  {
    "name": "Weather Talk",
    "words": ["sol", "regn", "skyet", "vind", "storm", "snø", "varmt", "kaldt", "lunkent", "friskt", "værprognose", "paraply", "jakke", "temperatur", "grader", "årstid", "fuktig", "tørt"]
  },
  {
    "name": "In the Supermarket",
    "words": [
      "handlekurv",
      "handlekorg",
      "gang",
      "kasse",
      "kasserer",
      "kvittering",
      "pose",
      "frukt",
      "grønnsaker",
      "brød",
      "meieriprodukter",
      "kjøtt",
      "frossen",
      "hermetisk",
      "hylle",
      "pris",
      "salg",
      "strekkode",
      "kontanter",
      "kort"
    ]
  },
  {
    "name": "Asking for Directions",
    "words": ["kart", "gate", "vei", "aveny", "venstre", "høyre", "rett frem", "hjørne", "kvartal", "trafikklys", "kryss", "svinge", "nær", "langt", "bak", "foran", "ved siden av", "mellom", "overfor", "skilt"]
  },
  {
    "name": "Essential Conversations",
    "words": ["hei", "hallo", "hvordan går det", "bra", "takk", "du", "vær", "bra", "dårlig", "opptatt", "sliten", "helg", "planer", "nyte", "i dag", "i morgen", "i går", "hyggelig", "møte", "igjen"]
  },
  {
    "name": "At the Airport",
    "words": [
      "boardingkort",
      "pass",
      "bagasje",
      "innsjekking",
      "sikkerhetskontroll",
      "gate",
      "fly",
      "forsinkelse",
      "avgang",
      "ankomst",
      "terminal",
      "bagasjeutlevering",
      "toll",
      "billett",
      "sete",
      "ombordstigning",
      "håndbagasje",
      "barnevogn",
      "visum",
      "taxfree"
    ]
  },
  {
    "name": "At the Restaurant",
    "words": [
      "meny",
      "servitør",
      "reservasjon",
      "bestilling",
      "forrett",
      "hovedrett",
      "dessert",
      "regning",
      "tips",
      "drikke",
      "vann",
      "vin",
      "øl",
      "gaffel",
      "kniv",
      "skje",
      "tallerken",
      "glass",
      "serviett",
      "spesialitet"
    ]
  },
  {
    "name": "At the Hotel",
    "words": [
      "resepsjon",
      "innsjekking",
      "utsjekking",
      "rom",
      "nøkkel",
      "reservasjon",
      "bagasje",
      "heis",
      "frokost",
      "wi-fi",
      "dusj",
      "håndkle",
      "seng",
      "pute",
      "teppe",
      "klimaanlegg",
      "vaskeri",
      "service",
      "safe",
      "utsikt"
    ]
  },
  {
    "name": "At the Doctor's Office",
    "words": [
      "time",
      "lege",
      "sykepleier",
      "symptomer",
      "smerte",
      "feber",
      "hoste",
      "hodepine",
      "resept",
      "medisin",
      "apotek",
      "allergi",
      "blodtrykk",
      "temperatur",
      "stetoskop",
      "bandasje",
      "injeksjon",
      "røntgen",
      "diagnose",
      "behandling"
    ]
  },
  {
    "name": "Public Transportation",
    "words": [
      "buss",
      "tog",
      "t-bane",
      "billett",
      "stasjon",
      "stopp",
      "ruteplan",
      "kart",
      "rute",
      "plattform",
      "billettpris",
      "overgang",
      "passasjer",
      "sjåfør",
      "konduktør",
      "forsinkelse",
      "utgang",
      "inngang",
      "sete",
      "stående"
    ]
  },
  {
    "name": "Shopping for Clothes",
    "words": ["skjorte", "bukser", "kjole", "sko", "størrelse", "farge", "pris", "salg", "prøverom", "kasserer", "kvittering", "pose", "jakke", "genser", "skjørt", "hatt", "sokker", "jeans", "belte", "rabatt"]
  },
  {
    "name": "At the Gym",
    "words": [
      "tredemølle",
      "vekter",
      "yoga",
      "tøying",
      "trener",
      "medlemskap",
      "skap",
      "dusj",
      "håndkle",
      "vannflaske",
      "trening",
      "kondisjon",
      "styrke",
      "repetisjoner",
      "sett",
      "oppvarming",
      "nedkjøling",
      "manual",
      "stang",
      "maskin"
    ]
  },
  {
    "name": "At the Bank",
    "words": [
      "konto",
      "uttak",
      "innskudd",
      "lån",
      "rente",
      "kredittkort",
      "debetkort",
      "minibank",
      "bankfunksjonær",
      "saldo",
      "valuta",
      "veksling",
      "sjekk",
      "sparing",
      "investering",
      "passord",
      "pin",
      "kontoutskrift",
      "gebyr",
      "overføring"
    ]
  },
  {
    "name": "At the Post Office",
    "words": [
      "pakke",
      "brev",
      "frimerke",
      "konvolutt",
      "adresse",
      "postkort",
      "pakke",
      "levering",
      "sporing",
      "postkasse",
      "avsender",
      "mottaker",
      "vekt",
      "størrelse",
      "prioritet",
      "ekspress",
      "luftpost",
      "toll",
      "gebyr",
      "kvittering"
    ]
  },
  {
    "name": "At the Pharmacy",
    "words": [
      "medisin",
      "resept",
      "smertestillende",
      "bandasje",
      "vitaminer",
      "hostesaft",
      "allergi",
      "krem",
      "salve",
      "pille",
      "tablett",
      "kapsel",
      "farmasøyt",
      "dosering",
      "bivirkninger",
      "etterfylling",
      "antibiotika",
      "termometer",
      "maske",
      "desinfeksjonsmiddel"
    ]
  },
  {
    "name": "At the Park",
    "words": ["benk", "tre", "gress", "sti", "lekeplass", "fontene", "hund", "piknik", "sykkel", "jogging", "blomster", "dam", "and", "skygge", "sol", "barn", "huske", "sklie", "søppelbøtte", "statue"]
  },
  {
    "name": "At the Beach",
    "words": ["sand", "bølger", "sol", "parasoll", "håndkle", "badedrakt", "solkrem", "solbriller", "hatt", "skjell", "måke", "hav", "tidevann", "surfing", "brett", "snorkling", "maske", "finner", "strandball", "is"]
  },
  {
    "name": "At the Library",
    "words": [
      "bok",
      "hylle",
      "katalog",
      "låne",
      "returnere",
      "forfallsdato",
      "bibliotekar",
      "studere",
      "stille",
      "pult",
      "stol",
      "datamaskin",
      "internett",
      "magasin",
      "avis",
      "fiksjon",
      "ikke-fiksjon",
      "referanse",
      "lån",
      "kort"
    ]
  },
  {
    "name": "At the Cinema",
    "words": [
      "billett",
      "film",
      "popcorn",
      "drikke",
      "sete",
      "lerret",
      "trailer",
      "sjanger",
      "skrekk",
      "komedie",
      "action",
      "drama",
      "romantikk",
      "regissør",
      "skuespiller",
      "skuespillerinne",
      "undertekster",
      "3d",
      "visningstid",
      "kiosk"
    ]
  },
  {
    "name": "At the Hair Salon",
    "words": ["hårklipp", "sjampo", "balsam", "frisør", "saks", "kam", "føning", "farge", "striper", "klipp", "pannelugg", "krøller", "retting", "timebestilling", "speil", "stol", "kappe", "barberhøvel", "gel", "spray"]
  }
];
