/// Runtime config for the AgakAI backend.
///
/// Mirrors the repo-root .env file. Only the public ANON key belongs here —
/// NEVER put the service_role key in client code.
class AppConfig {
  static const String supabaseUrl = 'https://nkstwuyayvzncisjaghg.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5rc3R3dXlheXZ6bmNpc2phZ2hnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3ODM0ODAsImV4cCI6MjEwMjM1OTQ4MH0.oB24PuOLB4c67sFidiS0b9K1tWYPPkMOPOPbdXJNhO0';
}