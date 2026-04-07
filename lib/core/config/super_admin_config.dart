const superAdminEmails = <String>{'jafaralituraev@gmail.com'};

String normalizeSuperAdminEmail(String? email) {
  return (email ?? '').trim().toLowerCase();
}

bool isSuperAdminEmail(String? email) {
  return superAdminEmails.contains(normalizeSuperAdminEmail(email));
}
