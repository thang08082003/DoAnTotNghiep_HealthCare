import 'package:healthcare/data/models/help_guide_model.dart';
import 'package:healthcare/data/models/user_model.dart';

/// DataSource layer for Help content.
/// Currently returns local static guides. Can be replaced with remote source.
class HelpService {
  Future<HelpGuide> getGuide(UserRole role) async {
    // Simulate I/O if needed in future (e.g., load from assets or network)
    return DefaultHelpGuides.forRole(role);
  }
}
