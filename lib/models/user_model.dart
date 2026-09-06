import 'gamer_user_model.dart';
export 'gamer_user_model.dart';

/// Alias for GamerUser matching standard UserModel naming.
/// Contains [verificationStatus] ('pending' | 'verified' | 'rejected' | 'none')
/// and [isVerified] (false by default).
typedef UserModel = GamerUser;
