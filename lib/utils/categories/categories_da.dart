const categories = [
  {
    "name": "At the Coffee Shop",
    "words": ["kaffe", "te", "mælk", "sukker", "kop", "bestilling", "menu", "bord", "barista", "kvittering", "byttepenge", "to-go", "is", "varm", "ske", "serviet", "fløde", "espresso", "latte", "drikkepenge"]
  },
  {
    "name": "Weather Talk",
    "words": ["solrig", "regnfuld", "skyet", "blæsende", "stormfuld", "sne", "varm", "kold", "lun", "kølig", "vejrudsigt", "paraply", "frakke", "temperatur", "grader", "sæson", "fugtig", "tør"]
  },
  {
    "name": "In the Supermarket",
    "words": ["vogn", "kurv", "gang", "kasse", "kasserer", "kvittering", "pose", "frugt", "grøntsager", "brød", "mejeri", "kød", "frossen", "konserves", "hylde", "pris", "tilbud", "stregkode", "kontanter", "kort"]
  },
  {
    "name": "Asking for Directions",
    "words": ["kort", "gade", "vej", "avenue", "venstre", "højre", "ligeud", "hjørne", "blok", "trafiklys", "kryds", "drej", "nær", "fjern", "bagved", "foran", "ved siden af", "mellem", "overfor", "skilt"]
  },
  {
    "name": "Making Small Talk",
    "words": ["hej", "dav", "hvordan", "fint", "tak", "dig", "vejr", "godt", "dårligt", "travlt", "træt", "weekend", "planer", "nyd", "i dag", "i morgen", "i går", "dejligt", "møde", "igen"]
  },
  {
    "name": "At the Airport",
    "words": [
      "boardingpas",
      "pas",
      "bagage",
      "check-in",
      "sikkerhed",
      "gate",
      "fly",
      "forsinkelse",
      "afgang",
      "ankomst",
      "terminal",
      "bagageudlevering",
      "told",
      "billet",
      "sæde",
      "boarding",
      "håndbagage",
      "klapvogn",
      "visum",
      "toldfri"
    ]
  },
  {
    "name": "At the Restaurant",
    "words": ["menu", "tjener", "reservation", "bestilling", "forret", "hovedret", "dessert", "regning", "drikkepenge", "drik", "vand", "vin", "øl", "gaffel", "kniv", "ske", "tallerken", "glas", "serviet", "special"]
  },
  {
    "name": "At the Hotel",
    "words": [
      "reception",
      "check-in",
      "check-out",
      "værelse",
      "nøgle",
      "reservation",
      "bagage",
      "elevator",
      "morgenmad",
      "wi-fi",
      "brusebad",
      "håndklæde",
      "seng",
      "pude",
      "tæppe",
      "aircondition",
      "vaskeri",
      "service",
      "sikker",
      "udsigt"
    ]
  },
  {
    "name": "At the Doctor's Office",
    "words": [
      "aftale",
      "læge",
      "sygeplejerske",
      "symptomer",
      "smerte",
      "feber",
      "hoste",
      "hovedpine",
      "recept",
      "medicin",
      "apotek",
      "allergi",
      "blodtryk",
      "temperatur",
      "stetoskop",
      "bandage",
      "injektion",
      "røntgen",
      "diagnose",
      "behandling"
    ]
  },
  {
    "name": "Public Transportation",
    "words": ["bus", "tog", "metro", "billet", "station", "stop", "køreplan", "kort", "rute", "perron", "pris", "skift", "passager", "chauffør", "konduktør", "forsinkelse", "udgang", "indgang", "sæde", "stående"]
  },
  {
    "name": "Shopping for Clothes",
    "words": ["skjorte", "bukser", "kjole", "sko", "størrelse", "farve", "pris", "tilbud", "prøverum", "kasserer", "kvittering", "pose", "jakke", "sweater", "nederdel", "hat", "sokker", "jeans", "bælte", "rabat"]
  },
  {
    "name": "At the Gym",
    "words": [
      "løbebånd",
      "vægte",
      "yoga",
      "udstrækning",
      "træner",
      "medlemskab",
      "skab",
      "brusebad",
      "håndklæde",
      "vandflaske",
      "træning",
      "cardio",
      "styrke",
      "gentagelser",
      "sæt",
      "opvarmning",
      "nedkøling",
      "håndvægt",
      "vægtstang",
      "maskine"
    ]
  },
  {
    "name": "At the Bank",
    "words": [
      "konto",
      "hævning",
      "indbetaling",
      "lån",
      "rente",
      "kreditkort",
      "betalingskort",
      "hæveautomat",
      "kassedame",
      "saldo",
      "valuta",
      "veksling",
      "check",
      "opsparing",
      "investering",
      "adgangskode",
      "pinkode",
      "kontoudtog",
      "gebyr",
      "overførsel"
    ]
  },
  {
    "name": "At the Post Office",
    "words": [
      "pakke",
      "brev",
      "frimærke",
      "kuvert",
      "adresse",
      "postkort",
      "pakke",
      "levering",
      "sporing",
      "postkasse",
      "afsender",
      "modtager",
      "vægt",
      "størrelse",
      "prioritet",
      "ekspres",
      "luftpost",
      "told",
      "gebyr",
      "kvittering"
    ]
  },
  {
    "name": "At the Pharmacy",
    "words": [
      "medicin",
      "recept",
      "smertestillende",
      "bandage",
      "vitaminer",
      "hostesaft",
      "allergi",
      "creme",
      "salve",
      "pille",
      "tablet",
      "kapsel",
      "apoteker",
      "dosis",
      "bivirkninger",
      "genopfyldning",
      "antibiotikum",
      "termometer",
      "maske",
      "desinfektionsmiddel"
    ]
  },
  {
    "name": "At the Park",
    "words": ["bænk", "træ", "græs", "sti", "legeplads", "springvand", "hund", "picnic", "cykel", "jogging", "blomster", "dam", "and", "skygge", "sol", "børn", "gynge", "rutsjebane", "skraldespand", "statue"]
  },
  {
    "name": "At the Beach",
    "words": ["sand", "bølger", "sol", "parasol", "håndklæde", "badedragt", "solcreme", "solbriller", "hat", "skaller", "måge", "hav", "tidevand", "surf", "bræt", "snorkel", "maske", "finner", "strandbold", "is"]
  },
  {
    "name": "At the Library",
    "words": [
      "bog",
      "hylde",
      "katalog",
      "låne",
      "returnere",
      "afleveringsdato",
      "bibliotekar",
      "studere",
      "stille",
      "skrivebord",
      "stol",
      "computer",
      "internet",
      "magasin",
      "avis",
      "fiktion",
      "faglitteratur",
      "reference",
      "lån",
      "kort"
    ]
  },
  {
    "name": "At the Cinema",
    "words": [
      "billet",
      "film",
      "popcorn",
      "drik",
      "sæde",
      "lærred",
      "trailer",
      "genre",
      "gyser",
      "komedie",
      "action",
      "drama",
      "romantik",
      "instruktør",
      "skuespiller",
      "skuespillerinde",
      "undertekster",
      "3d",
      "spilletid",
      "slikbutik"
    ]
  },
  {
    "name": "At the Hair Salon",
    "words": [
      "klipning",
      "shampoo",
      "balsam",
      "frisør",
      "saks",
      "kam",
      "føntørring",
      "farve",
      "reflekser",
      "trimning",
      "pandehår",
      "krøller",
      "glatte",
      "aftale",
      "spejl",
      "stol",
      "kappe",
      "barbermaskine",
      "gel",
      "hårspray"
    ]
  }
];
