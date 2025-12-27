import 'package:healthcare/data/models/help_guide_model.dart';
import 'package:healthcare/data/models/user_model.dart';
import 'package:healthcare/data/services/help_service.dart';

class HelpRepository {
  final HelpService _service;

  HelpRepository({HelpService? service}) : _service = service ?? HelpService();

  Future<HelpGuide> getGuideForRole(UserRole role) {
    return _service.getGuide(role);
  }
}
