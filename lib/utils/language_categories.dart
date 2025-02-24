import 'package:parakeet/utils/categories/categories_en_US.dart' as en_us;
import 'package:parakeet/utils/categories/categories_en_AU.dart' as en_au;
import 'package:parakeet/utils/categories/categories_en_GB.dart' as en_gb;
import 'package:parakeet/utils/categories/categories_ar.dart' as ar;
import 'package:parakeet/utils/categories/categories_bn.dart' as bn;
import 'package:parakeet/utils/categories/categories_cmn.dart' as cmn;
import 'package:parakeet/utils/categories/categories_da.dart' as da;
import 'package:parakeet/utils/categories/categories_de.dart' as de;
import 'package:parakeet/utils/categories/categories_es_ES.dart' as es_es;
import 'package:parakeet/utils/categories/categories_es_US.dart' as es_us;
import 'package:parakeet/utils/categories/categories_fil.dart' as fil;
import 'package:parakeet/utils/categories/categories_fr_CA.dart' as fr_ca;
import 'package:parakeet/utils/categories/categories_fr_FR.dart' as fr_fr;
import 'package:parakeet/utils/categories/categories_gu.dart' as gu;
import 'package:parakeet/utils/categories/categories_hi.dart' as hi;
import 'package:parakeet/utils/categories/categories_id.dart' as id;
import 'package:parakeet/utils/categories/categories_it.dart' as it;
import 'package:parakeet/utils/categories/categories_ja.dart' as ja;
import 'package:parakeet/utils/categories/categories_kn.dart' as kn;
import 'package:parakeet/utils/categories/categories_ko.dart' as ko;
import 'package:parakeet/utils/categories/categories_ml.dart' as ml;
import 'package:parakeet/utils/categories/categories_ms.dart' as ms;
import 'package:parakeet/utils/categories/categories_nb.dart' as nb;
import 'package:parakeet/utils/categories/categories_pa.dart' as pa;
import 'package:parakeet/utils/categories/categories_pl.dart' as pl;
import 'package:parakeet/utils/categories/categories_pt_BR.dart' as pt_br;
import 'package:parakeet/utils/categories/categories_pt_PT.dart' as pt_pt;
import 'package:parakeet/utils/categories/categories_ru.dart' as ru;
import 'package:parakeet/utils/categories/categories_sv.dart' as sv;
import 'package:parakeet/utils/categories/categories_ta.dart' as ta;
import 'package:parakeet/utils/categories/categories_tr.dart' as tr;
import 'package:parakeet/utils/categories/categories_vi.dart' as vi;

/// Returns the categories list for the specified target language.
/// Falls back to English (US) if the language is not supported.
List<Map<String, dynamic>> getCategoriesForLanguage(String targetLanguage) {
  switch (targetLanguage) {
    case 'English (US)':
      return en_us.categories;
    case 'English (Australia)':
      return en_au.categories;
    case 'English (UK)':
      return en_gb.categories;
    case 'Arabic':
      return ar.categories;
    case 'Bengali':
      return bn.categories;
    case 'Chinese':
      return cmn.categories;
    case 'Danish':
      return da.categories;
    case 'German':
      return de.categories;
    case 'Spanish (Spain)':
      return es_es.categories;
    case 'Spanish (Mexico)':
      return es_us.categories;
    case 'Filipino':
      return fil.categories;
    case 'French (Canada)':
      return fr_ca.categories;
    case 'French (France)':
      return fr_fr.categories;
    case 'Gujarati':
      return gu.categories;
    case 'Hindi':
      return hi.categories;
    case 'Indonesian':
      return id.categories;
    case 'Italian':
      return it.categories;
    case 'Japanese':
      return ja.categories;
    case 'Kannada':
      return kn.categories;
    case 'Korean':
      return ko.categories;
    case 'Malayalam':
      return ml.categories;
    case 'Malay':
      return ms.categories;
    case 'Norwegian':
      return nb.categories;
    case 'Punjabi':
      return pa.categories;
    case 'Polish':
      return pl.categories;
    case 'Portuguese (Brazil)':
      return pt_br.categories;
    case 'Portuguese (Portugal)':
      return pt_pt.categories;
    case 'Russian':
      return ru.categories;
    case 'Swedish':
      return sv.categories;
    case 'Tamil':
      return ta.categories;
    case 'Turkish':
      return tr.categories;
    case 'Vietnamese':
      return vi.categories;
    default:
      return en_us.categories;
  }
}

/// List of supported languages
final List<String> supportedLanguages = [
  'English (US)',
  'English (AU)',
  'English (GB)',
  'Arabic',
  'Bengali',
  'Chinese',
  'Danish',
  'German',
  'Spanish (ES)',
  'Spanish (US)',
  'Filipino',
  'French (CA)',
  'French (FR)',
  'Gujarati',
  'Hindi',
  'Indonesian',
  'Italian',
  'Japanese',
  'Kannada',
  'Korean',
  'Malayalam',
  'Malay',
  'Norwegian',
  'Punjabi',
  'Polish',
  'Portuguese (BR)',
  'Portuguese (PT)',
  'Russian',
  'Swedish',
  'Tamil',
  'Turkish',
  'Vietnamese',
];
