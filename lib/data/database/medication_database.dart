import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class MedicationDatabase {
  static final MedicationDatabase instance = MedicationDatabase._init();
  static Database? _database;

  MedicationDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medications.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // Insert 100 medication names
    final medications = [
      'Empatince',
      'Dorunavir 75',
      'Fabalina 5/25',
      'Fabalina 5/10',
      'Strongfil-40',
      'Viên sủi Pafenol 500mg',
      'Loratadin 10mg Kingphar',
      'Ibuprofen 400 mg Kingphar',
      'Acetylcystein 200mg Kingphar',
      'Glipizid 5 mg',
      'Sitagliptin Plus XR',
      'Lukair',
      'Mzynof',
      'Wedoll - S 100',
      'Mitimipid 100 ODT',
      'Solmebe',
      'Solcoex 600',
      'Solbose 50 ODT',
      'Solfazin',
      'Misoprostol 100',
      'Lercanidipine 20',
      'Histavert ODT',
      'Herouracil',
      'Herolac',
      'Heragemci 200',
      'Heragemci 1000',
      'Heraclovir DT 800',
      'Henobicin',
      'Cytobicil',
      'Doxycyclin',
      'Domperidon',
      'Acyclovir 5%',
      'Supergra 50',
      'Supergra 100',
      'Pira 800-LTF',
      'Mirfan 15',
      'Losartan-LTF 50',
      'Lopramid-LTF',
      'Lipis-LTF 20',
      'Lipis-LTF 10',
      'Lafancol extra',
      'Lacinda 300',
      'Lacele-xib 200',
      'Flozinga 5',
      'Flozinga 10',
      'Fegut 120',
      'Dovran 200',
      'Clopido-LTF',
      'Cobamol 1500',
      'Sitagliptin 25 mg',
      'Cofatorid 50',
      'Amlosali',
      'Tadalafil 20mg',
      'Tadalafil 5mg',
      'Orlistat 120 mg',
      'Ibucodeine STELLA 200/ 12.8',
      'Abiraterone STELLA 250 mg',
      'Hacutrol 5',
      'Furosemid 40',
      'Diosmin Hasan 600',
      'Diosmibe DT',
      'DH-Enamigal 5',
      'DH-Enamigal 10',
      'Captopril Hydroclorothiazid 25/ 12,5',
      'Captocom 25/ 25',
      'Mivifort 850/ 50',
      'Hapizide 10',
      'Vicsoytine',
      'Sulpirid',
      'Plainic',
      'Lopegoric',
      'Eltomax',
      'Vplaxol',
      'Adaflo AG 500',
      'Bilantihis 10 DT',
      'Fexosin 30',
      'Precozil 250',
      'Ecophelic 180',
      'Mexlocap 20',
      'Dromerin 80',
      'Dexchlorpheniramine maleate -Betamethasone 2.0 / 0.25',
      'Debrudan 100',
      'BV Ibugesic Fort',
      'BV Carbocistein 500',
      'Bivogyl',
      'Bivibismol',
      'Aluminum hydroxide-Magnesium hydroxide-Simethicone 175/ 200/ 25',
      'Triflogilse',
      'DRP-Dapa 5',
      'DRP-Dapa 10',
      'PT Micolin',
      'Nimomia',
      'Migesten 200mg',
      'Pamephrin tab',
      'Rafoexplores',
      'Edotin',
      'Duganka',
      'Betamineo',
      'Levocinco',
      'Dealkey',
    ];

    for (final med in medications) {
      await db.insert('medications', {'name': med});
    }
  }

  Future<List<String>> getAllMedications() async {
    final db = await instance.database;
    final result = await db.query('medications', orderBy: 'name ASC');
    return result.map((row) => row['name'] as String).toList();
  }

  Future<List<String>> searchMedications(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'medications',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((row) => row['name'] as String).toList();
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
